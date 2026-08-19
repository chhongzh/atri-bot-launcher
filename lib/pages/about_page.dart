import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static final _launcherUri = Uri.parse(
    'https://github.com/chhongzh/atri-bot-launcher',
  );
  static final _atriBotUri = Uri.parse('https://github.com/chhongzh/atri-bot');
  static final _authorUri = Uri.parse('https://github.com/chhongzh');

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('关于', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Atri Bot Launcher',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '喜欢 Atri Bot Launcher？',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('欢迎到 GitHub 点个 Star，支持启动器继续开发。'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openUrl(context, _atriBotUri),
                      icon: const Icon(Icons.star_outline),
                      label: const Text('给Atri-Bot点个 Star'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openUrl(context, _launcherUri),
                      icon: const Icon(Icons.star_outline),
                      label: const Text('给启动器点个 Star'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.balance_outlined),
                title: Text('开源协议'),
                subtitle: Text('MIT License'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.rocket_launch_outlined),
                title: const Text('启动器地址'),
                subtitle: const Text('github.com/chhongzh/atri-bot-launcher'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openUrl(context, _launcherUri),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text('atri-bot 地址'),
                subtitle: const Text('github.com/chhongzh/atri-bot'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openUrl(context, _atriBotUri),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () => _openUrl(context, _authorUri),
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            label: const Text('chhongzh · made with love'),
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('无法打开链接：$uri')));
  }
}
