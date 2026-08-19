import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/release.dart';
import '../services/log_service.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = Get.find<LogService>();
    return Obx(
      () => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '启动器与内核日志',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: logs.entries.isEmpty
                    ? null
                    : () => _confirmShare(context, logs.entries),
                icon: const Icon(Icons.ios_share_outlined),
                tooltip: '导出并分享日志',
              ),
              IconButton(
                onPressed: logs.clear,
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: '清空日志',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${logs.entries.length} 条结构化记录'),
          const SizedBox(height: 16),
          if (logs.entries.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('暂无日志'),
                subtitle: Text('下载、安装和启动过程的日志会显示在这里。'),
              ),
            )
          else
            ...logs.entries.map(
              (log) => Card(
                child: ListTile(
                  leading: Icon(
                    log.level == 'error'
                        ? Icons.error_outline
                        : log.level == 'warn'
                        ? Icons.warning_amber
                        : Icons.info_outline,
                    color: _levelColor(context, log.level),
                  ),
                  title: Text(
                    log.message,
                    style: TextStyle(color: _levelColor(context, log.level)),
                  ),
                  subtitle: Text(log.timestamp?.toLocal().toString() ?? '即时日志'),
                  trailing: IconButton(
                    onPressed: () => _showFields(context, log),
                    icon: const Icon(Icons.data_object),
                    tooltip: '查看日志详情',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _levelColor(BuildContext context, String level) {
    final scheme = Theme.of(context).colorScheme;
    return switch (level) {
      'error' => scheme.error,
      'warn' => scheme.tertiary,
      _ => scheme.primary,
    };
  }

  void _showFields(BuildContext context, LogEntry log) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日志消息'),
            subtitle: SelectableText(log.message),
            trailing: IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: log.message));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('日志消息已复制')));
              },
              icon: const Icon(Icons.copy_outlined),
              tooltip: '复制消息',
            ),
          ),
          if (log.fields.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(log.fields),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmShare(
    BuildContext context,
    List<LogEntry> entries,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('分享前请检查日志'),
        content: const Text(
          '日志中虽已尽可能处理，尽量避免包含 API Key、Bot Token 等敏感信息，但仍可能有所遗漏。分享前请自行检查日志内容，确认没有需要隐藏的信息。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('检查后分享'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final filename =
          'atri-bot-log-${DateTime.now().millisecondsSinceEpoch}.txt';
      final content = entries
          .map(
            (log) => [
              '[${log.timestamp?.toLocal().toIso8601String() ?? '即时日志'}] [${log.level.toUpperCase()}] ${log.message}',
              if (log.fields.isNotEmpty)
                const JsonEncoder.withIndent('  ').convert(log.fields),
            ].join('\n'),
          )
          .join('\n\n');

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final location = await getSaveLocation(
          suggestedName: filename,
          acceptedTypeGroups: [
            const XTypeGroup(label: '文本文件', extensions: ['txt']),
          ],
        );
        if (location == null) return;
        await File(location.path).writeAsString(content);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日志已导出')));
        return;
      }

      final directory = await getTemporaryDirectory();
      await directory.create(recursive: true);
      final file = File(p.join(directory.path, filename));
      await file.writeAsString(content);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Atri Bot 日志',
          text: 'Atri Bot 启动器日志',
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出日志失败：$error')));
    }
  }
}
