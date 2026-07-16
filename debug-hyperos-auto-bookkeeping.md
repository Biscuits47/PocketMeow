[OPEN] HyperOS auto bookkeeping debugging

## Session
- session_id: `hyperos-auto-bookkeeping`
- date: 2026-07-16
- scope:
  - HyperOS 3.0 上无障碍服务无法开启，出现“未知来源应用”限制
  - 自动记账似乎只在打开具体账单详情时触发，通知栏记录未稳定触发
  - App 更新后无障碍服务开关失效
  - 后续还需处理支出分布图与默认分类改动

## Hypotheses
1. AndroidManifest 中无障碍服务、权限、`exported`、queries 或 receiver/service 声明与 HyperOS 3.0 的权限策略存在冲突，导致系统把服务视为高风险来源。
2. 自动记账主流程实际只在无障碍节点解析路径里完成，通知栏监听仅做采集或预处理，没有走到统一入账链路。
3. 应用升级后包签名、安装覆盖、组件 enable 状态或系统缓存导致 HyperOS 将已授予的无障碍授权重置为“假开启”或直接失效。
4. 无障碍服务配置文件、前台服务/广播接收器生命周期、开机或更新后自检逻辑缺失，导致权限状态没有被正确识别和引导恢复。
5. 饼图当前标签布局算法仅适合较少分类，阈值和图例/引导线策略过于保守，导致分类数量少且标签容易重叠。

## Evidence Log
- Static inspection confirmed:
  - Manifest 已声明无障碍服务与通知监听服务，且 `exported="true"`、`canPerformGestures="true"` 均已具备。
  - 工程内不存在 `PACKAGE_REPLACED` / `MY_PACKAGE_REPLACED` / `BOOT_COMPLETED` 相关恢复 receiver，更新后无障碍失效时缺少恢复引导链路。
  - 通知监听链路会真实入账，但解析规则偏保守，详情页与历史账单页解析远强于通知文本解析。
  - HyperOS 相关用户指引此前仅在说明文案中轻量提示，未明确提示“允许受限设置/未知来源应用”。

## Applied Mitigations
1. App 恢复到前台时自动同步自动记账监听状态，减少更新后或权限切换后的假开启/假失效状态残留。
2. 设置页补充 HyperOS / Android 13+ “允许受限设置”排障说明，并在无障碍权限项中给出更直接提示。
3. 通知自动记账放宽支付关键词与金额提取规则，提升仅靠通知文本时的命中率。
4. 饼图与分类交互相关需求已一并实现：缩小图形、降低“其他”阈值、增强标签避让、支出默认分类改为“日用”且排第一。

## Next Steps
1. Inspect Android manifest, accessibility service declarations, notification listener flow, and unified auto-bookkeeping pipeline.
2. Inspect update/permission status checks and any HyperOS-specific guidance logic.
3. Inspect expense distribution chart rendering and category ordering/default selection logic.
