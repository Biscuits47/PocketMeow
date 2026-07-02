import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/bill_import_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';

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
  final controller = TextEditingController(
    text: store.totalBudget.toStringAsFixed(0),
  );

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('修改月预算'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '输入本月总预算'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                store.updateTotalBudget(value);
              }
              Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
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
      int count = 0;
      if (file.extension?.toLowerCase() == 'csv') {
        count = await _billImportService.importAlipayBill(file, store);
      } else if (file.extension?.toLowerCase() == 'xlsx') {
        count = await _billImportService.importWeChatBill(file, store);
      }

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $count 笔账单')),
        );
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
        SnackBar(content: Text('数据已导出至: ${file.path}')),
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

Future<void> _checkForUpdates(BuildContext context) async {
  _showLoadingDialog(context, message: '正在检查远端版本清单...');
  try {
    final info = await _appUpdateService.checkForUpdate();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    await showDialog<void>(
      context: context,
      builder: (context) {
        final releaseNotes =
            info.releaseNotes.isEmpty ? '这次更新暂未填写说明。' : info.releaseNotes;
        final downloadLabel = info.downloadUrl == null ? '查看详情' : '下载更新';
        return AlertDialog(
          title: Text(info.hasUpdate ? '发现新版本' : '已经是最新版本'),
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
                      : '当前安装版本已经不低于版本清单中的最新版本。',
                ),
                const SizedBox(height: 14),
                Text(
                  '清单来源',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  info.manifestUrl,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  '更新说明',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(releaseNotes),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(info.hasUpdate ? '稍后' : '关闭'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (info.downloadUrl != null &&
                    info.downloadUrl!.endsWith('.apk')) {
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
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('检查更新失败：$error')),
    );
  }
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

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200 && response.statusCode != 302) {
        throw Exception('下载失败，状态码: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/PocketMeow_update.apk');
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _progress = downloadedBytes / contentLength;
            _statusText = '正在下载... ${(_progress * 100).toStringAsFixed(1)}%';
          });
        }
      }

      await sink.close();

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusText = '下载完成，准备安装...';
          _isDownloading = false;
        });
      }

      final result = await OpenFilex.open(file.path);
      if (mounted) {
        Navigator.of(context).pop(); // close dialog
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('安装文件打开失败: ${result.message}')),
          );
        }
      }
    } catch (e) {
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
        if (!_isDownloading)
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
