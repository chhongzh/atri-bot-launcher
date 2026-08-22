import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import '../models/release.dart';
import 'executable_service.dart';
import 'log_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

enum KernelState { stopped, starting, running, stopping, failed }

class KernelService extends GetxService {
  KernelService(
    this.settings,
    this.notifications,
    this.logService,
    this.executables,
  );

  final SettingsService settings;
  final NotificationService notifications;
  final LogService logService;
  final ExecutableService executables;
  final state = KernelState.stopped.obs;
  final lastExitCode = RxnInt();
  final directStartFailed = false.obs;
  final error = RxnString();

  Process? _process;

  RxList<LogEntry> get logs => logService.entries;

  bool get isRunning =>
      state.value == KernelState.running || state.value == KernelState.starting;

  Future<void> start() async {
    if (isRunning) return;
    final executable = settings.executablePath.value;
    if (executable.isEmpty || !await File(executable).exists()) {
      throw StateError('还没有安装 Atri Bot 内核');
    }
    state.value = KernelState.starting;
    error.value = null;
    directStartFailed.value = false;
    lastExitCode.value = null;
    logService.info('准备启动内核', {
      'executable': executable,
      'arguments': const <String>[],
    });
    try {
      await executables.prepare(executable);
      await settings.alignConfigPathWithExecutable();
      final workingDirectory = Directory(path.dirname(executable));
      await workingDirectory.create(recursive: true);
      final process = await Process.start(
        executable,
        const <String>[],
        workingDirectory: workingDirectory.path,
        runInShell: false,
      );
      _process = process;
      state.value = KernelState.running;
      logService.info('内核已启动', {
        'pid': process.pid,
        'working_directory': workingDirectory.path,
      });
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(logService.addProcessLine);
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(logService.addProcessLine);
      process.exitCode.then(_handleExit);
    } catch (exception) {
      state.value = KernelState.failed;
      error.value = '$exception';
      if (Platform.isAndroid) directStartFailed.value = true;
      logService.error('内核启动失败', {
        'executable': executable,
        'error': '$exception',
      });
      rethrow;
    }
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    state.value = KernelState.stopping;
    process.kill(ProcessSignal.sigterm);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_process != null) process.kill(ProcessSignal.sigkill);
  }

  void clearLogs() => logService.clear();

  Future<void> _handleExit(int exitCode) async {
    if (_process == null) return;
    _process = null;
    lastExitCode.value = exitCode;
    final wasStopping = state.value == KernelState.stopping;
    state.value = exitCode == 0 || wasStopping
        ? KernelState.stopped
        : KernelState.failed;
    final fields = {'exit_code': exitCode};
    if (exitCode == 0) {
      logService.info('内核已退出', fields);
    } else {
      logService.error('内核异常退出', fields);
    }
    if (!wasStopping) await notifications.showProcessExit(exitCode);
  }
}
