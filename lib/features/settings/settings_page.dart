import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/state/pocket_meow_store.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/app_update_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_models.dart';

final _appUpdateService = AppUpdateService();

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
    final theme = Theme.of(context);
    final store = PocketMeowScope.watch(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Text('我的', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '预算、分类、数据安全和更新都放在这里。',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 20),
          _ProfileCard(
              totalBudget: store.totalBudget, monthSpent: store.monthSpent),
          const SizedBox(height: 16),
          _SettingTile(
            icon: Icons.savings_outlined,
            title: '月预算设置',
            subtitle: '当前总预算 ${formatShortCurrency(store.totalBudget)}',
            onTap: () => _showBudgetDialog(context, store),
          ),
          _CategoryManagerCard(categories: store.categories),
          const SizedBox(height: 16),
          _SettingTile(
            icon: Icons.verified_user_outlined,
            title: '数据安全',
            subtitle: '账单保存在本地数据库，覆盖安装更新不会清空',
            onTap: () => _showDataSafetyDialog(context, store),
          ),
          const _AppVersionTile(),
          const _SettingTile(
            icon: Icons.notifications_outlined,
            title: '提醒设置',
            subtitle: '预算预警与每日记账提醒',
          ),
          _SettingTile(
            icon: Icons.refresh_rounded,
            title: '恢复初始状态',
            subtitle: '保留默认分类和预算，并清空当前账单',
            onTap: store.resetDemoData,
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.totalBudget,
    required this.monthSpent,
  });

  final double totalBudget;
  final double monthSpent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.mint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.pets_rounded, color: AppTheme.mintDeep),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('钱喵', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '本月已花 ${formatShortCurrency(monthSpent)} / 预算 ${formatShortCurrency(totalBudget)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
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
        final versionText = info == null
            ? '正在读取当前版本...'
            : '当前版本 v${info.version} (${info.buildNumber})';
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

class _CategoryManagerCard extends StatelessWidget {
  const _CategoryManagerCard({required this.categories});

  final List<ExpenseCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = PocketMeowScope.read(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('分类管理', style: theme.textTheme.titleLarge),
                ),
                FilledButton.tonal(
                  onPressed: () => _showAddCategoryDialog(context, store),
                  child: const Text('新增分类'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            Color(category.colorValue).withValues(alpha: 0.14),
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
          ],
        ),
      ),
    );
  }
}

Future<void> _showBudgetDialog(
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

Future<void> _showAddCategoryDialog(
  BuildContext context,
  PocketMeowStore store,
) async {
  final nameController = TextEditingController();
  RecordType type = RecordType.expense;
  String iconKey = 'wallet';
  int colorValue = 0xFF63D3B1;
  const colorOptions = [
    0xFF63D3B1,
    0xFF8FA8FF,
    0xFFFF8A5B,
    0xFFB39DDB,
    0xFF6FC3D6,
    0xFFE57373,
  ];

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
                          width: 72,
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                option.icon,
                                color:
                                    selected ? AppTheme.mintDeep : AppTheme.ink,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                option.label,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: colorValue,
                    items: colorOptions
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Color(item),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '#${item.toRadixString(16).substring(2).toUpperCase()}'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        colorValue = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: '颜色'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '分类仅用于记账统计，不单独设置预算。',
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

Future<void> _showDataSafetyDialog(
  BuildContext context,
  PocketMeowStore store,
) async {
  _showLoadingDialog(context, message: '正在读取数据存储信息...');
  try {
    final summary = await store.dataSafetySummary();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('数据安全说明'),
          content: Text(summary),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('读取数据存储信息失败，请稍后重试。')),
    );
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
                Text('当前版本：${info.currentVersion} (${info.currentBuild})'),
                const SizedBox(height: 6),
                Text('最新版本：${info.latestVersion} (${info.latestBuild})'),
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
                await _openReleaseDownload(
                  context,
                  info.downloadUrl ?? info.detailsUrl,
                );
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
      const SnackBar(content: Text('无法打开下载链接，请稍后重试。')),
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
