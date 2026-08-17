import 'dart:io';

import 'package:get/get.dart';

import 'log_service.dart';

class ExecutableService extends GetxService {
  ExecutableService(this.logs);

  final LogService logs;

  Future<void> prepare(String filePath) async {
    final type = await FileSystemEntity.type(filePath);
    if (type != FileSystemEntityType.file) {
      throw FileSystemException('内核路径不是普通文件', filePath);
    }
    if (Platform.isMacOS) {
      await _removeAttribute(filePath, 'com.apple.quarantine');
      await _removeAttribute(filePath, 'com.apple.provenance');
    }
    if (Platform.isWindows) return;
    final result = await Process.run('chmod', ['u+x', filePath]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        '无法设置执行权限：${'${result.stderr}'.trim()}',
        filePath,
      );
    }
    logs.info('内核执行权限已准备完成', {'path': filePath});
  }

  Future<void> _removeAttribute(String filePath, String attribute) async {
    final result = await Process.run('/usr/bin/xattr', [
      '-d',
      attribute,
      filePath,
    ]);
    if (result.exitCode == 0) {
      logs.info('已移除 macOS 隔离属性', {'path': filePath, 'attribute': attribute});
    }
  }
}
