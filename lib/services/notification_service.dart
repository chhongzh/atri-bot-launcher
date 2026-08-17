import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class NotificationService extends GetxService {
  final _notifications = FlutterLocalNotificationsPlugin();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<NotificationService> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    try {
      await _notifications.initialize(settings);
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {}
    return this;
  }

  Future<void> showProcessExit(int exitCode) async {
    showSnackBar(
      '内核已停止',
      exitCode == 0 ? 'atri-bot 已正常退出' : 'atri-bot 异常退出（代码 $exitCode）',
    );
    try {
      await _notifications.show(
        1001,
        'atri-bot 内核已停止',
        exitCode == 0 ? '进程已正常退出' : '进程异常退出，退出码：$exitCode',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'atri_bot_process',
            '进程状态',
            channelDescription: 'atri-bot 内核进程状态通知',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  void showSnackBar(String title, String message, {bool persistent = false}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title：$message'),
          duration: persistent
              ? const Duration(seconds: 8)
              : const Duration(seconds: 4),
          action: SnackBarAction(
            label: '知道了',
            onPressed: messenger.hideCurrentSnackBar,
          ),
        ),
      );
  }
}
