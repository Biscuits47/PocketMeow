[OPEN] Chart label and plugin crash debugging

## Session
- session_id: `chart-label-plugin-crash`
- date: 2026-07-16
- scope:
  - 支出分布饼图注释线仍会视觉错位，出现一个分类像有两个注释、另一个没有注释
  - 导入数据库备份后触发 `MissingPluginException`，报 `isPermissionGranted` on `x-slayer/notifications_channel`

## Hypotheses
1. 当前饼图标签单折角路径的拐点位置不稳定，导致线条穿越相邻扇区，引起视觉错配。
2. 左右两侧标签避让后只调整了终点 Y，没有同步采用固定侧边走廊，导致小分类密集时线条交叉。
3. 备份导入完成后触发了自动记账监听刷新，而当前平台并不是 Android，因此通知监听插件未注册。
4. 自动记账服务在 `startListening` / `syncListeningWithPermissions` 中缺少平台判断，任何平台都会直接触发插件通道调用。
5. 导入流程本身成功，但后置状态恢复或 Store 重新加载时调用了移动端专属插件，最终抛出缺失插件实现。

## Evidence Log
- Code inspection confirmed:
  - 饼图标签当前使用单折角路径，但折点直接采用标签目标 Y，导致小扇区密集时线条在饼图附近穿插，出现视觉错配。
  - 备份导入入口 `settings_page.dart::_importData()` 仅调用 `store.importData(jsonStr)`，导入本身不直接使用通知插件。
  - `PocketMeowStore.load()` 与自动记账刷新链路会在 `_isAutoBookkeepingEnabled` 时触发 `autoBookkeepingService.startListening()` / `syncListeningWithPermissions()`。
  - `AutoBookkeepingService` 原实现未做平台保护，直接调用 `NotificationListenerService.isPermissionGranted()`，与截图中的 `MissingPluginException` 一致。

## Applied Mitigations
1. 饼图引导线改为稳定的左右侧边走廊折点，避免折线穿入相邻扇区导致“注释跑到别的分类旁边”。
2. 自动记账服务增加 Android 平台保护；在非 Android 或插件缺失时直接降级为不启动监听。
3. 通知权限与无障碍权限查询增加 `MissingPluginException` / `PlatformException` 兜底，避免导入备份等流程因插件未注册而崩溃。

## Next Steps
1. Inspect pie label overlay path construction and layout ordering.
2. Inspect backup import flow and store reload path.
3. Inspect all notification listener plugin calls and add platform-safe guards if evidence confirms.
