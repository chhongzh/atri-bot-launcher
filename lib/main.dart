import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/app_controller.dart';
import 'pages/app_shell.dart';
import 'services/config_service.dart';
import 'services/executable_service.dart';
import 'services/kernel_service.dart';
import 'services/log_service.dart';
import 'services/network_service.dart';
import 'services/notification_service.dart';
import 'services/release_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Get.putAsync<SettingsService>(
    () => SettingsService().init(),
    permanent: true,
  );
  final notifications = await Get.putAsync<NotificationService>(
    () => NotificationService().init(),
    permanent: true,
  );
  final logs = Get.put(LogService(), permanent: true);
  final network = await Get.putAsync<NetworkService>(
    () => NetworkService(logs).init(),
    permanent: true,
  );
  final executables = Get.put(ExecutableService(logs), permanent: true);
  final releases = Get.put(
    ReleaseService(settings, logs, executables, network.client),
    permanent: true,
  );
  final kernel = Get.put(
    KernelService(settings, notifications, logs, executables),
    permanent: true,
  );
  final config = Get.put(ConfigService(), permanent: true);
  Get.put(
    AppController(settings, releases, kernel, config, notifications),
    permanent: true,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    return GetMaterialApp(
      title: 'Atri Bot Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: Get.find<NotificationService>().messengerKey,
      home: const AppShell(),
    );
  }
}
