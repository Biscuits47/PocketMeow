import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/bill_import_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';
import '../budget/budget_manager_sheet.dart';

final _appUpdateService = AppUpdateService();
final _billImportService = BillImportService();

Future<void> openSettingsPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const _SettingsScaffold(),
    ),
  );
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: const SettingsPage(),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PocketMeowScope.watch(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          _SettingTile(
            icon: Icons.category_rounded,
            title: '分类管理',
            subtitle: '新增或删除自定义记账分类',
            onTap: () => _openCategoryManager(context),
          ),
          _SettingTile(
            icon: Icons.auto_awesome_rounded,
            title: '自动记账',
            subtitle: '通过监听通知或无障碍服务自动记录微信/支付宝账单',
            onTap: () => _openAutoBookkeepingSettings(context, store),
          ),
          _SettingTile(
            icon: Icons.sync_alt_rounded,
            title: '导入导出数据',
            subtitle: '备份或恢复本地记账数据',
            onTap: () => _openImportExportMenu(context, store),
          ),
          _SettingTile(
            icon: Icons.notifications_outlined,
            title: '提醒设置',
            subtitle: '预算预警与每日记账提醒',
            onTap: () => _openReminderSettings(context),
          ),
          const _AppVersionTile(),
        ],
      ),
    );
  }
}

void _openCategoryManager(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const _CategoryManagerPage(),
    ),
  );
}

class _CategoryManagerPage extends StatelessWidget {
  const _CategoryManagerPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.watch(context);

    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () => showAddCategoryDialog(context, store),
              child: const Text('新增分类'),
            ),
          ),
          const SizedBox(height: 14),
          ...store.categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(category.colorValue)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          iconForCategory(category.iconKey),
                          size: 18,
                          color: Color(category.colorValue),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${category.name} · ${category.type.label}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (!category.isSystem)
                        IconButton(
                          onPressed: () => _confirmDeleteCategory(
                            context,
                            store,
                            category,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openImportExportMenu(BuildContext context, PocketMeowStore store) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '数据管理',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('导入微信/支付宝账单'),
              subtitle: const Text('支持解析 CSV 和 Excel 格式'),
              onTap: () {
                Navigator.of(context).pop();
                _importBill(context, store);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('导出完整数据 (备份)'),
              subtitle: const Text('保存为 JSON 格式的备份文件'),
              onTap: () {
                Navigator.of(context).pop();
                _exportData(context, store);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_page_rounded),
              title: const Text('导入完整数据 (恢复)'),
              subtitle: const Text('读取之前导出的备份文件'),
              onTap: () {
                Navigator.of(context).pop();
                _importData(context, store);
              },
            ),
          ],
        ),
      );
    },
  );
}

void _openAutoBookkeepingSettings(BuildContext context, PocketMeowStore store) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _AutoBookkeepingPage(store: store),
    ),
  );
}

class _AutoBookkeepingPage extends StatefulWidget {
  const _AutoBookkeepingPage({required this.store});
  final PocketMeowStore store;

  @override
  State<_AutoBookkeepingPage> createState() => _AutoBookkeepingPageState();
}

class _AutoBookkeepingPageState extends State<_AutoBookkeepingPage>
    with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _accGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final notif = await NotificationListenerService.isPermissionGranted();
    final acc =
        await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    if (mounted) {
      setState(() {
        _notifGranted = notif;
        _accGranted = acc;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.store.isAutoBookkeepingEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('自动记账')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: isEnabled ? AppTheme.mint.withValues(alpha: 0.1) : null,
            child: SwitchListTile(
              title: const Text('开启自动记账'),
              subtitle: const Text('在后台自动解析微信和支付宝的动账通知/支付页面'),
              value: isEnabled,
              onChanged: (value) {
                widget.store.setAutoBookkeepingEnabled(value);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('权限状态', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(
              Icons.notifications_active_rounded,
              color: _notifGranted ? AppTheme.mintDeep : AppTheme.warning,
            ),
            title: const Text('通知读取权限'),
            subtitle: Text(_notifGranted ? '已授权' : '未授权，点击去开启'),
            trailing: _notifGranted
                ? const Icon(Icons.check_circle, color: AppTheme.mintDeep)
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await NotificationListenerService.requestPermission();
              await _checkPermissions();
              if (widget.store.isAutoBookkeepingEnabled &&
                  (_notifGranted || _accGranted)) {
                await widget.store.refreshAutoBookkeepingListening();
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.accessibility_new_rounded,
              color: _accGranted ? AppTheme.mintDeep : AppTheme.warning,
            ),
            title: const Text('无障碍服务权限'),
            subtitle: Text(
              _accGranted
                  ? '已授权。若 HyperOS 重启 App 后偶发不工作，可先点下方“重新同步自动记账引擎”；若仍无效，再去系统无障碍页手动关闭后重新打开一次。'
                  : '未授权，点击去开启。HyperOS / Android 13+ 若提示未知来源或受限设置，请先到应用信息里允许受限设置。',
            ),
            trailing: _accGranted
                ? const Icon(Icons.check_circle, color: AppTheme.mintDeep)
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await FlutterAccessibilityService
                  .requestAccessibilityPermission();
              await _checkPermissions();
              if (widget.store.isAutoBookkeepingEnabled &&
                  (_notifGranted || _accGranted)) {
                await widget.store.refreshAutoBookkeepingListening();
              }
            },
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () async {
              await widget.store.refreshAutoBookkeepingListening();
              await _checkPermissions();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '已重新同步自动记账引擎；如果 HyperOS 仍显示已开但无记录，请去系统无障碍页手动关闭后重新打开一次。',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.sync_rounded),
            label: const Text('重新同步自动记账引擎'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFE1AF)),
            ),
            child: Text(
              'HyperOS 常见限制：\n'
              '1. 如果无障碍页显示“未知来源应用”或“无法开启”，请先进入系统设置 > 应用管理 > 钱喵 > 右上角更多/菜单 > 允许受限设置。\n'
              '2. 如果是应用内下载或手动安装的更新包，系统更容易把无障碍视为高风险，更新后要重新确认权限状态。\n'
              '3. 建议同时打开自启动、无限制后台、锁定后台，并关闭省电限制，否则通知监听和无障碍都可能被系统拦截。\n'
              '4. 更新完成后回到 App，本页会自动重新检查权限状态；如果显示已开但不生效，通常需要手动关闭再重新打开一次无障碍。',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: const Color(0xFF7A5A16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('运行说明', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Text(
              '1. 建议同时开启【通知读取】和【无障碍】权限以提高自动记账成功率。\n2. 已内置去重机制，同一笔交易如果在1分钟内被通知和无障碍同时捕获，只会记录一次。\n3. 查看微信/支付宝历史账单列表或单条账单详情页时，当前屏幕中识别到的记录也会自动补记。\n4. 红米 / HyperOS 设备请额外打开【自启动】、【无限制后台】、【锁定后台】并关闭省电限制，否则系统可能拦截通知监听或无障碍事件。'),
        ],
      ),
    );
  }
}

void _openReminderSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReminderSettingsSheet(),
  );
}

class _ReminderSettingsSheet extends StatefulWidget {
  const _ReminderSettingsSheet();

  @override
  State<_ReminderSettingsSheet> createState() => _ReminderSettingsSheetState();
}

class _ReminderSettingsSheetState extends State<_ReminderSettingsSheet> {
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  double _warningPercent = 85.0;
  bool _enableReminder = false;
  bool _enableWarning = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('提醒设置', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('每日记账提醒'),
              subtitle: const Text('在指定时间提醒你记录当天的花销'),
              value: _enableReminder,
              onChanged: (value) {
                setState(() => _enableReminder = value);
                if (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已开启每日记账提醒')),
                  );
                }
              },
            ),
            if (_enableReminder) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提醒时间'),
                trailing: Text(_time.format(context),
                    style: theme.textTheme.titleMedium),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (time != null) {
                    setState(() => _time = time);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('提醒时间已修改为 ${_time.format(context)}')),
                      );
                    }
                  }
                },
              ),
            ],
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('预算超支预警'),
              subtitle: const Text('当预算消耗过快且剩余天数较多时进行提醒'),
              value: _enableWarning,
              onChanged: (value) => setState(() => _enableWarning = value),
            ),
            if (_enableWarning) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('预警阈值', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  Text('${_warningPercent.toInt()}%',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: AppTheme.warning)),
                ],
              ),
              Slider(
                value: _warningPercent,
                min: 50,
                max: 100,
                divisions: 10,
                activeColor: AppTheme.warning,
                label: '${_warningPercent.toInt()}%',
                onChanged: (value) => setState(() => _warningPercent = value),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.ink),
          ),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final versionText =
            info == null ? '正在读取当前版本...' : '当前版本 v${info.version}';
        return _SettingTile(
          icon: Icons.system_update_alt_rounded,
          title: '检查更新',
          subtitle: '$versionText\n从远端版本清单检查并下载最新 APK',
          onTap: () => _checkForUpdates(context),
        );
      },
    );
  }
}

Future<void> showBudgetDialog(
  BuildContext context,
  PocketMeowStore store,
) async {
  await showBudgetManagerSheet(context);
}

Future<void> showAddCategoryDialog(
  BuildContext context,
  PocketMeowStore store,
) async {
  final nameController = TextEditingController();
  RecordType type = RecordType.expense;
  String iconKey = 'wallet';

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('新增自定义分类'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: '分类名称'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RecordType>(
                    initialValue: type,
                    items: RecordType.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        type = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: '类型'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '图标库',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: kCategoryIconOptions.map((option) {
                      final selected = option.key == iconKey;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            iconKey = option.key;
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.mint.withValues(alpha: 0.16)
                                : const Color(0xFFF1F4F6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.mintDeep
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            option.icon,
                            color: selected ? AppTheme.mintDeep : AppTheme.ink,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '分类仅用于记账统计，不单独设置预算。新分类的颜色将会自动随机生成。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  final colorValue = Colors
                      .primaries[Random().nextInt(Colors.primaries.length)]
                      .toARGB32();
                  store.addCategory(
                    name: name,
                    type: type,
                    iconKey: iconKey,
                    colorValue: colorValue,
                    limit: 0,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _importBill(BuildContext context, PocketMeowStore store) async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (result != null && result.files.isNotEmpty) {
      if (!context.mounted) return;
      _showLoadingDialog(context, message: '正在导入账单...');
      final file = result.files.first;
      ImportResult? importResult;
      if (file.extension?.toLowerCase() == 'csv') {
        importResult = await _billImportService.importAlipayBill(file, store);
      } else if (file.extension?.toLowerCase() == 'xlsx') {
        importResult = await _billImportService.importWeChatBill(file, store);
      }

      if (context.mounted && importResult != null) {
        Navigator.of(context, rootNavigator: true).pop();

        if (importResult.invalidRecords.isNotEmpty) {
          await _showInvalidRecordsDialog(context, store, importResult);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功导入 ${importResult.importedCount} 笔账单')),
          );
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }
}

Future<void> _showInvalidRecordsDialog(
  BuildContext context,
  PocketMeowStore store,
  ImportResult importResult,
) async {
  final invalidRecords = importResult.invalidRecords;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('检测到 ${invalidRecords.length} 笔已失效交易'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '在本次导入的账单中，以下交易被标记为"退款"、"交易关闭"或"不计收支"，但它们目前仍存在于您的软件记录中。是否一键删除它们？',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: invalidRecords.length,
                  itemBuilder: (context, index) {
                    final record = invalidRecords[index];
                    return ListTile(
                      title: Text(record.note,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(formatDayLabel(record.createdAt)),
                      trailing: Text(
                        formatCurrency(record.amount),
                        style: TextStyle(
                          color: record.type == RecordType.expense
                              ? const Color(0xFFE57373)
                              : const Color(0xFF81C784),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '成功导入 ${importResult.importedCount} 笔账单 (保留了失效交易)')),
              );
            },
            child: const Text('保留'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.warning,
            ),
            onPressed: () {
              for (final record in invalidRecords) {
                store.deleteRecord(record.id);
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '成功导入 ${importResult.importedCount} 笔，并清理了 ${invalidRecords.length} 笔失效交易'),
                ),
              );
            },
            child: const Text('一键删除'),
          ),
        ],
      );
    },
  );
}

Future<void> _exportData(BuildContext context, PocketMeowStore store) async {
  _showLoadingDialog(context, message: '正在导出数据...');
  try {
    final jsonStr = await store.exportData();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    // Save to file
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/PocketMeow_Backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据已导出，正在唤起分享...')),
      );
      // Share the file
// ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '这是我的钱喵记账数据备份文件',
        subject: '钱喵记账数据备份',
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }
}

Future<void> _importData(BuildContext context, PocketMeowStore store) async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.isNotEmpty) {
      if (!context.mounted) return;
      _showLoadingDialog(context, message: '正在恢复数据...');

      final file = result.files.first;
      String? jsonStr;
      if (file.bytes != null) {
        jsonStr = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        jsonStr = await File(file.path!).readAsString();
      }

      if (jsonStr != null) {
        await store.importData(jsonStr);
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据恢复成功')),
          );
        }
      } else {
        throw Exception('无法读取文件内容');
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }
}

Future<void> checkForUpdatesAndPrompt(
  BuildContext context, {
  bool showProgressDialog = false,
  bool showLatestDialog = false,
  bool showErrors = false,
  bool respectIgnoredRelease = false,
}) async {
  if (showProgressDialog) {
    _showLoadingDialog(context, message: '正在检查远端版本清单...');
  }
  try {
    final info = await _appUpdateService.checkForUpdate();
    if (!context.mounted) {
      return;
    }
    if (showProgressDialog) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    final isIgnored = await _appUpdateService.isIgnoredRelease(info);
    if (!context.mounted) {
      return;
    }
    if (info.hasUpdate && respectIgnoredRelease && isIgnored) {
      return;
    }
    if (!info.hasUpdate && !showLatestDialog) {
      return;
    }

    await _showUpdateResultDialog(
      context,
      info,
      isIgnored: isIgnored,
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    if (showProgressDialog) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (showErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败：$error')),
      );
    }
  }
}

Future<void> _checkForUpdates(BuildContext context) {
  return checkForUpdatesAndPrompt(
    context,
    showProgressDialog: true,
    showLatestDialog: true,
    showErrors: true,
  );
}

Future<void> _showUpdateResultDialog(
  BuildContext context,
  AppUpdateInfo info, {
  required bool isIgnored,
}) {
  final releaseNotes =
      info.releaseNotes.isEmpty ? '这次更新暂未填写说明。' : info.releaseNotes;
  final isSameRelease = info.latestVersion == info.currentVersion &&
      info.latestBuild == info.currentBuild;
  final canDownloadCurrentRelease = info.hasUpdate || isSameRelease;
  final downloadLabel =
      info.downloadUrl == null ? '查看详情' : (info.hasUpdate ? '下载更新' : '重新下载');
  final hasDownloadableApk =
      info.downloadUrl != null && info.downloadUrl!.endsWith('.apk');
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          info.hasUpdate ? (isIgnored ? '发现新版本（已忽略提醒）' : '发现新版本') : '已经是最新版本',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本：${info.currentVersion}'),
              const SizedBox(height: 6),
              Text('最新版本：${info.latestVersion}'),
              if (info.publishedAt != null) ...[
                const SizedBox(height: 6),
                Text('发布时间：${_formatUpdateTime(info.publishedAt!)}'),
              ],
              const SizedBox(height: 14),
              Text(
                info.hasUpdate
                    ? '检测到新版本，可以直接从版本清单里的下载地址获取最新 APK。'
                    : (isSameRelease
                        ? '当前安装版本与版本清单一致，你仍然可以重新下载这个版本的 APK。'
                        : '当前安装版本已经不低于版本清单中的最新版本。'),
              ),
              if (info.hasUpdate && isIgnored) ...[
                const SizedBox(height: 10),
                const Text('这个版本的启动提醒已被忽略，但你仍然可以在这里手动下载更新。'),
              ],
              if (canDownloadCurrentRelease && !hasDownloadableApk) ...[
                const SizedBox(height: 10),
                const Text('当前版本清单里没有直接 APK 下载地址，将为你打开发布详情页。'),
              ],
              const SizedBox(height: 14),
              Text(
                '更新说明',
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(releaseNotes),
            ],
          ),
        ),
        actions: [
          if (info.hasUpdate && !isIgnored)
            TextButton(
              onPressed: () async {
                await _appUpdateService.ignoreRelease(info);
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '已忽略 v${info.latestVersion}，在下一个版本发布前不会再提醒。',
                    ),
                  ),
                );
              },
              child: const Text('忽略本次'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(info.hasUpdate ? '稍后' : '关闭'),
          ),
          if (canDownloadCurrentRelease)
            FilledButton(
              onPressed: () async {
                await _appUpdateService.clearIgnoredRelease();
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                if (hasDownloadableApk) {
                  await _downloadAndInstallApk(context, info.downloadUrl!);
                } else {
                  await _openReleaseDownload(context, info.detailsUrl);
                }
              },
              child: Text(downloadLabel),
            ),
        ],
      );
    },
  );
}

void _showLoadingDialog(BuildContext context, {required String message}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      );
    },
  );
}

Future<void> _openReleaseDownload(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开链接，请稍后重试。')),
    );
  }
}

Future<void> _downloadAndInstallApk(BuildContext context, String url) async {
  // Use a stateful dialog to show download progress
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _DownloadApkDialog(url: url);
    },
  );
}

class _DownloadApkDialog extends StatefulWidget {
  const _DownloadApkDialog({required this.url});
  final String url;

  @override
  State<_DownloadApkDialog> createState() => _DownloadApkDialogState();
}

class _DownloadApkDialogState extends State<_DownloadApkDialog> {
  double _progress = 0.0;
  String _statusText = '准备下载...';
  bool _isDownloading = true;
  final http.Client _client = http.Client();
  bool _isCancelled = false;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _isCancelled = true;
    _client.close();
    try {
      if (_tempFile?.existsSync() ?? false) {
        _tempFile?.deleteSync();
      }
    } catch (_) {}
    super.dispose();
  }

  Future<void> _startDownload() async {
    try {
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await _client.send(request);

      if (response.statusCode != 200 && response.statusCode != 302) {
        throw Exception('下载失败，状态码: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;

      final dir = await getTemporaryDirectory();
      _tempFile = File('${dir.path}/PocketMeow_update.apk');
      final sink = _tempFile!.openWrite();
      bool success = false;

      try {
        await for (final chunk in response.stream) {
          if (_isCancelled) {
            await sink.close();
            if (_tempFile!.existsSync()) {
              _tempFile!.deleteSync();
            }
            return;
          }
          sink.add(chunk);
          downloadedBytes += chunk.length;
          if (contentLength > 0 && mounted) {
            setState(() {
              _progress = downloadedBytes / contentLength;
              _statusText = '正在下载... ${(_progress * 100).toStringAsFixed(1)}%';
            });
          }
        }
        await sink.flush();
        success = true;
      } finally {
        await sink.close();
      }

      if (_isCancelled || !success) return;

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusText = '下载完成，准备安装...';
          _isDownloading = false;
        });
      }

      _tempFile = null; // Prevent dispose from deleting it right after
      final result = await OpenFilex.open('${dir.path}/PocketMeow_update.apk');
      if (mounted) {
        Navigator.of(context).pop(); // close dialog
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('安装文件打开失败: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (_isCancelled) return;
      if (mounted) {
        setState(() {
          _statusText = '下载出错: $e';
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('下载更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusText),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _isDownloading ? (_progress > 0 ? _progress : null) : 1.0,
          ),
        ],
      ),
      actions: [
        if (_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}

String _formatUpdateTime(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hh:$mm';
}

Future<void> _confirmDeleteCategory(
  BuildContext context,
  PocketMeowStore store,
  ExpenseCategory category,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('删除 ${category.name}?'),
        content: const Text('如果该分类已经被账单使用，则不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              store.deleteCategory(category.id);
              Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
}
