# Debug Session: auto-bookkeeping-crash

- Status: OPEN
- User symptom 1: 自动记账功能失效，无法自动记账
- User symptom 2: 软件放后台后重新打开会闪退
- Scope: 自动记账、应用前后台切换、无障碍/通知监听链路

## Hypotheses

1. `refreshAutoBookkeepingListening()` 在应用恢复时触发了异常的重复重连或插件调用。
2. 无障碍页面门控条件过严，导致真实目标页被拦截，自动记账看起来完全失效。
3. 数据库升级到 `version 5` 后，旧数据或持久化路径存在兼容问题，在恢复到前台时触发崩溃。
4. vendored 原生无障碍服务页面预判逻辑访问节点树时触发原生异常。
5. 后台恢复时通知监听/无障碍监听重启流程中的异步状态竞争导致崩溃并连带使自动记账失效。

## Plan

1. 只做插桩，不修改业务逻辑。
2. 对应用恢复、自动记账重连、无障碍事件门控、通知监听恢复加调试日志。
3. 让用户复现一次“后台回来闪退”和“自动记账失效”。
4. 根据日志确认根因后再做最小修复。

## Evidence

- 用户确认：自动记账设置页中“通知读取权限”和“无障碍服务权限”都显示已授权。
- 用户确认：点击“重新同步自动记账引擎”后，通知自动记账和账单详情补记都仍然完全无反应。
- 静态证据：`refreshAutoBookkeepingListening()` 进入 `syncListeningWithPermissions()` 后调用的是 `startListening()`。
- 静态证据：`startListening()` 在 `_isListening == true` 且订阅对象仍非空时会直接返回，不会真正重新绑定系统监听。

## Analysis

- Hypothesis A: CONFIRMED
  - “重新同步自动记账引擎”存在假刷新问题，满足条件时会提前返回，无法真正重连通知监听和无障碍监听。
- Hypothesis B: INCONCLUSIVE
  - 无障碍页面门控过严仍有可能存在，但当前更上游的“假刷新”已足够解释通知链路和详情页链路同时失效。
- Hypothesis C: REJECTED
  - 当前未再出现后台恢复闪退，且问题稳定表现为监听无响应，不像数据库兼容导致的恢复崩溃。
- Hypothesis D: INCONCLUSIVE
  - 原生页面预判是否过严暂无运行时日志支撑。
- Hypothesis E: CONFIRMED
  - 系统监听失活后，应用内状态仍认为自身“正在监听”，导致恢复和手动同步都无法自愈。

## Fix

- 已将 `syncListeningWithPermissions()` 改为 `startListening(forceRestart: true)`，确保前台恢复和手动同步都会真正强制重连。
- 调试日志 `runId` 已切换为 `post-fix`，等待用户验证修复结果。
