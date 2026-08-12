# LiteTodo Motion / Animation Audit

审计日期：2026-08-12

目标风格：Fast、Subtle、Predictable、Desktop-oriented。

## 审计范围

全局搜索关键字：

```text
AnimationController
AnimatedContainer
AnimatedOpacity
AnimatedScale
AnimatedSize
AnimatedSwitcher
FadeTransition
ScaleTransition
SlideTransition
Transform.scale
Transform.translate
showDialog
showGeneralDialog
showShadDialog
ShadDialog
ShadPopover
ShadSheet
.animate()
FadeEffect
ScaleEffect
MoveEffect
```

## 结论表

| 组件 | 当前实现 | 当前 duration | 当前 curve | 存在的问题 | 修改方案 |
| --- | --- | --- | --- | --- | --- |
| shadcn_ui 默认 Dialog Route | `showShadDialog` 默认 `FadeEffect + ScaleEffect(.95 -> 1)` | 约 200ms | shadcn 默认 | Scale 幅度偏大，barrier 默认较重，容易出现明显“放大弹出”感 | 新增 `showAppDialog`，统一传入 `0.985 -> 1`、Y 6px、160ms enter、110ms exit、轻 barrier |
| 项目创建 / 编辑 Dialog | `ProjectManagement.showCreateProject/showEditProject` 调用 shadcn 默认 route，内容本身是 `ShadDialog` | 约 200ms | shadcn 默认 | 使用第三方默认 motion，不受项目 token 控制 | 改为 `showAppDialog`，保留单一 route animation owner |
| 项目组编辑 Dialog | `ProjectManagement.showEditGroup` 调用 shadcn 默认 route | 约 200ms | shadcn 默认 | 与项目 Dialog 手感一致但未 token 化 | 改为 `showAppDialog` |
| 项目操作 Dialog | `ProjectManagement._showActions` 调用 shadcn 默认 route，内容外层 `Center + SizedBox + ShadDialog` | 约 200ms | shadcn 默认 | 没有重复外层 scale，但默认 scale 幅度仍偏大 | 改为 `showAppDialog` |
| 删除项目 / 解散项目确认 | `ProjectManagement._confirm` 调用 shadcn 默认 alert route | 约 200ms | shadcn 默认 | Alert 与普通 Dialog 进入手感不统一 | 改为 `showAppDialog`，内容仍使用 `ShadDialog.alert` |
| 回收站清空确认 | `TrashPage._confirmClear` 调用 shadcn 默认 alert route | 约 200ms | shadcn 默认 | barrier 过重，进入动效未统一 | 改为 `showAppDialog` |
| 导入确认 | `SettingsPage._confirmImport` 调用 shadcn 默认 alert route | 约 200ms | shadcn 默认 | 与其他确认框手感不统一 | 改为 `showAppDialog` |
| 第三方许可证 Dialog | `AboutSettingsSection._showLicenses` 调用 shadcn 默认 route | 约 200ms | shadcn 默认 | 内容较高时默认放大更明显 | 改为 `showAppDialog` |
| Tooltip | shadcn 主题默认 `Fade + Scale(.95 -> 1) + Move` | 默认 duration | shadcn 默认 | Tooltip 属于辅助信息，不应有 scale / slide | 在 `AppTheme` 覆盖为仅 Fade，80ms |
| Popover / 下拉 | shadcn 主题默认 `Fade + Scale(.95 -> 1) + Move(2px)` | 150ms | shadcn 默认 | 默认 scale 幅度偏大、时长略慢 | 在 `AppTheme` 覆盖为 `Fade + Scale(.98 -> 1) + Move(4px)`，110ms enter / 80ms exit |
| ShadCheckbox / ShadSwitch | shadcn 默认 100ms | shadcn 默认 | 当前基本合理，但未在项目层声明 | 在 `AppTheme` 明确设置为 `AppMotion.fast` |
| 主应用 Theme 切换 | `themeCurve: Threshold(0.0)`，builder 内直接 `ShadTheme` | 近似瞬切 | Threshold | 深浅主题会在下一帧直接跳变，可能出现整页闪变 | 改为 `ShadAnimatedTheme`，220ms，`easeInOutCubic` |
| 便签二级窗口 Theme 切换 | 与主应用一致，使用 `Threshold(0.0)` + `ShadTheme` | 近似瞬切 | Threshold | 主窗口与便签窗口主题 motion 不一致 | 改为 `ShadAnimatedTheme`，220ms，`easeInOutCubic` |
| Full / Compact / QuickAdd 模式切换 | `AppShell` 直接按 `WindowLifecycleState` 切换内容 | 无 Flutter 内容过渡 | 无 | 窗口 bounds 变化后内容可能突然替换 | 在内容层增加 140ms 淡入淡出，不做 scale，不改变 window bounds 流程 |
| Full Shell 页面切换 | `_RouteContent` 直接替换 Home / Statistics / Trash / Settings | 无 | 无 | 页面内容突然替换，Shell 稳定但主内容缺少状态过渡 | 仅 Main Content 使用 140ms fade + 约 4px Y 方向进入，Sidebar / Topbar 静止 |
| Home 筛选 Chip | `AnimatedContainer` | 100ms | 未显式 curve | duration 合理但未 token 化 | 改为 `AppMotion.fast` + `standardCurve` |
| Settings 分类 Rail | `AnimatedContainer` | 120ms | `Curves.easeOut` | 时长和 curve 与项目 motion token 不统一 | 改为 `AppMotion.fast` + `standardCurve` |
| Todo Row hover | `AnimatedContainer` 背景变化 | 100ms | `Curves.easeOut` 或局部默认 | hover 手感接近要求，但未 token 化 | 改为 `AppMotion.instant` + `standardCurve` |
| Todo Row hover actions | 条件渲染或不透明度切换 | 无或瞬切 | 无 | Hover 操作按钮出现略突然 | 改为 `AnimatedOpacity` 80ms，不改变行高 |
| Todo Row checkbox | `Container` 直接切换填充 / icon | 无 | 无 | 完成状态变化偏突然 | 改为 `AnimatedContainer` 120ms + `AnimatedSwitcher` 100ms |
| Todo Row title completed state | `TextStyle` 直接切换颜色 / 删除线 | 无 | 无 | 完成状态反馈偏硬 | 改为 `AnimatedDefaultTextStyle` 120ms；完成项仍留在列表中 |
| Todo Tree chevron | `chevronRight/chevronDown` 直接替换 | 无 | 无 | 展开折叠方向变化突然 | 改为 `AnimatedRotation`，160ms，`easeOutCubic` |
| Todo Tree 子项展开 | 仍基于 `VisibleTodoRow[] + ListView.builder` | 无逐条动画 | 无 | 没有视觉展开动画，但性能最稳 | 保持虚拟列表，不做子项 stagger / fade / slide |
| Sticky Notes Row hover | `AnimatedContainer`，duration 来自 `AppMetrics.hoverDurationMs` | 100ms | 未显式 curve | motion 参数在 metrics 中，不够集中 | 改为 `AppMotion.instant` + `standardCurve` |
| 拖拽反馈 | `Draggable.feedback` 使用静态 shadow | 无 | 无 | 未发现 animation tick 中复杂 shadow 动画 | 保持静态，不新增动画 |

## 风险项

- `workspace_controller`、`window_controller`、`json_settings_repository` 中的 250ms 是保存防抖 / 几何保存，不属于 UI motion，保留。
- Todo 树没有引入逐条进入动画，避免 1000 Todo 场景下产生大量 rebuild。
- 当前项目未发现业务组件自建 `AnimationController`。
- 当前项目未发现 `Curves.bounceOut`、`elastic`、大幅 `Transform.scale`、运行时 `BackdropFilter` 动画。
