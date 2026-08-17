import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../services/config_service.dart';

enum ConfigInputKind { text, number, secret, multiline, boolean, dropdown }

class ConfigOption {
  const ConfigOption(this.value, this.label);

  final String value;
  final String label;
}

class ConfigDefinition {
  const ConfigDefinition({
    required this.path,
    required this.title,
    required this.description,
    this.kind = ConfigInputKind.text,
    this.options = const [],
  });

  final String path;
  final String title;
  final String description;
  final ConfigInputKind kind;
  final List<ConfigOption> options;
}

class ConfigSectionDefinition {
  const ConfigSectionDefinition({
    required this.title,
    required this.description,
    required this.fields,
  });

  final String title;
  final String description;
  final List<ConfigDefinition> fields;
}

const _sections = [
  ConfigSectionDefinition(
    title: 'Telegram 机器人',
    description: '连接 Telegram 所需的凭据。Bot Token 是唯一必填项。',
    fields: [
      ConfigDefinition(
        path: 'telegram.bot_token',
        title: 'Bot Token',
        description: '从 Telegram 的 @BotFather 获取，保存后不会在界面中明文展示。',
        kind: ConfigInputKind.secret,
      ),
    ],
  ),
  ConfigSectionDefinition(
    title: '新用户默认值',
    description: '这些值只用于新用户，已有用户可以通过机器人命令单独修改。',
    fields: [
      ConfigDefinition(
        path: 'default.max_rounds',
        title: '默认对话轮数',
        description: '压缩历史记录前保留的完整 Telegram 对话轮数。',
        kind: ConfigInputKind.number,
      ),
      ConfigDefinition(
        path: 'default.image_max_edge',
        title: '图片最长边',
        description: '用户图片的最长边，最大支持 2048 像素。',
        kind: ConfigInputKind.number,
      ),
      ConfigDefinition(
        path: 'default.mcp_max_tools',
        title: 'MCP 工具数量上限',
        description: '每个用户可以加载的 MCP 工具数量上限。',
        kind: ConfigInputKind.number,
      ),
      ConfigDefinition(
        path: 'default.tool_permissions',
        title: '默认工具权限',
        description: '高级设置，使用 JSON 编辑工具名到 true/false 的权限映射。',
        kind: ConfigInputKind.multiline,
      ),
    ],
  ),
  ConfigSectionDefinition(
    title: '网络安全',
    description: '控制 atri-bot 是否允许访问本机和内网地址。',
    fields: [
      ConfigDefinition(
        path: 'security.allow_private_ip',
        title: '允许访问内网地址',
        description: '开启后 web_read 和 MCP 可以访问 localhost、局域网和私网 IP。',
        kind: ConfigInputKind.boolean,
      ),
    ],
  ),
  ConfigSectionDefinition(
    title: '数据库',
    description: 'atri-bot 用来保存账户、会话和工具配置。普通用户请选择 SQLite。',
    fields: [
      ConfigDefinition(
        path: 'database.type',
        title: '数据库类型',
        description: 'SQLite 不需要额外服务；MySQL 需要填写完整连接串。',
        kind: ConfigInputKind.dropdown,
        options: [
          ConfigOption('sqlite', 'SQLite（本地文件，推荐）'),
          ConfigOption('mysql', 'MySQL（服务器数据库）'),
        ],
      ),
      ConfigDefinition(
        path: 'database.path',
        title: 'SQLite 文件路径',
        description: '相对于 atri_cwd 的数据库文件路径。',
      ),
      ConfigDefinition(
        path: 'database.dsn',
        title: 'MySQL 连接串',
        description: '例如 user:pass@tcp(127.0.0.1:3306)/atri?parseTime=True。',
        kind: ConfigInputKind.secret,
      ),
    ],
  ),
  ConfigSectionDefinition(
    title: '外部服务',
    description: '可选的浏览器调试服务，用于启用网页读取工具。',
    fields: [
      ConfigDefinition(
        path: 'external.browser_url',
        title: '浏览器调试地址',
        description: '例如 127.0.0.1:9222；留空则不启用 web_read。',
      ),
    ],
  ),
  ConfigSectionDefinition(
    title: '本地文件',
    description: '控制媒体缓存的空间上限和清理周期。',
    fields: [
      ConfigDefinition(
        path: 'files.max_storage_mb',
        title: '媒体缓存上限（MB）',
        description: '本地媒体缓存允许占用的最大空间。',
        kind: ConfigInputKind.number,
      ),
      ConfigDefinition(
        path: 'files.cleanup_after',
        title: '媒体保留时间',
        description: '超过这个时间的媒体文件会被自动清理。',
        kind: ConfigInputKind.dropdown,
        options: [
          ConfigOption('1d', '1 天'),
          ConfigOption('3d', '3 天'),
          ConfigOption('7d', '7 天'),
          ConfigOption('30d', '30 天'),
        ],
      ),
    ],
  ),
  ConfigSectionDefinition(
    title: '运行目录',
    description: '角色文件、数据库和缓存都会按照这个目录组织。',
    fields: [
      ConfigDefinition(
        path: 'atri_cwd',
        title: 'atri-bot 数据目录',
        description: '留空或填写 . 表示使用启动器传入的当前工作目录。',
      ),
    ],
  ),
];

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Get.find<ConfigService>();
    return Obx(() {
      final revision = config.revision.value;
      if (config.loading.value && config.values.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return ConfigEditor(key: ValueKey('config-$revision'));
    });
  }
}

class ConfigEditor extends StatefulWidget {
  const ConfigEditor({super.key});

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor> {
  final config = Get.find<ConfigService>();
  late String databaseType;

  @override
  void initState() {
    super.initState();
    databaseType = '${config.valueAt('database.type') ?? 'sqlite'}';
  }

  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppController>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final horizontalPadding = compact ? 12.0 : 24.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            24,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '可视化配置',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => config.load(config.path.value),
                  icon: const Icon(Icons.refresh),
                  tooltip: '重新读取文件',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '修改完配置请记得滚动到页面底部点击保存',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (config.error.value != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('配置读取失败'),
                  subtitle: Text(config.error.value!),
                ),
              ),
            ..._sections.map(
              (section) => Card(
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(),
                  collapsedShape: const RoundedRectangleBorder(),
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 20,
                    vertical: compact ? 4 : 8,
                  ),
                  title: Text(section.title),
                  subtitle: Text(section.description),
                  children: [
                    ...section.fields
                        .where(_shouldShow)
                        .map(
                          (definition) => _buildField(
                            context,
                            definition,
                            compact: compact,
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: app.saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('保存配置'),
            ),
          ],
        );
      },
    );
  }

  bool _shouldShow(ConfigDefinition definition) {
    if (definition.path == 'database.path') return databaseType == 'sqlite';
    if (definition.path == 'database.dsn') return databaseType == 'mysql';
    return true;
  }

  Widget _buildField(
    BuildContext context,
    ConfigDefinition definition, {
    required bool compact,
  }) {
    final value = config.valueAt(definition.path);
    if (definition.kind == ConfigInputKind.boolean) {
      return SwitchListTile(
        title: Text(definition.title),
        subtitle: Text(definition.description),
        value: value == true,
        onChanged: (next) {
          config.setValue(definition.path, next);
          setState(() {});
        },
      );
    }
    if (definition.kind == ConfigInputKind.dropdown) {
      final selected =
          definition.options.any((option) => option.value == '$value')
          ? '$value'
          : definition.options.first.value;
      final dropdown = DropdownMenu<String>(
        initialSelection: selected,
        expandedInsets: compact ? EdgeInsets.zero : null,
        dropdownMenuEntries: definition.options
            .map(
              (option) => DropdownMenuEntry<String>(
                value: option.value,
                label: option.label,
              ),
            )
            .toList(),
        onSelected: (next) {
          if (next == null) return;
          config.setValue(definition.path, next);
          if (definition.path == 'database.type') {
            setState(() => databaseType = next);
          }
        },
      );
      if (!compact) {
        return ListTile(
          title: Text(definition.title),
          subtitle: Text(definition.description),
          trailing: dropdown,
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              definition.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              definition.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            dropdown,
          ],
        ),
      );
    }
    return ConfigTextField(
      key: ValueKey(definition.path),
      definition: definition,
      value: value,
      onChanged: (input) => config.setField(definition.path, input),
    );
  }
}

class ConfigTextField extends StatefulWidget {
  const ConfigTextField({
    required this.definition,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ConfigDefinition definition;
  final dynamic value;
  final ValueChanged<String> onChanged;

  @override
  State<ConfigTextField> createState() => _ConfigTextFieldState();
}

class _ConfigTextFieldState extends State<ConfigTextField> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: _displayValue(widget.value));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.definition.kind == ConfigInputKind.multiline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: widget.definition.kind == ConfigInputKind.secret,
        keyboardType: widget.definition.kind == ConfigInputKind.number
            ? const TextInputType.numberWithOptions(decimal: false)
            : multiline
            ? TextInputType.multiline
            : TextInputType.text,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 6 : 1,
        decoration: InputDecoration(
          labelText: widget.definition.title,
          helperText: widget.definition.description,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }

  String _displayValue(dynamic value) {
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value == null ? '' : '$value';
  }
}
