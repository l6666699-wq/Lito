# LiteTodo 开发进度

更新时间：2026-08-11（Asia/Shanghai）

## 当前状态

功能开发已进入 Phase 5（打磨与发布候选）。Phase 0 性能门槛仍未通过，也没有记录到正式豁免；后续阶段是按用户明确指示继续完成的，不能将性能门槛描述为已通过。

- 50 Todo Release 冷启动三次中位 Working Set：127.016 MiB，高于 120 MiB gate，但低于 140 MiB 停止阈值。
- 1000 Todo 默认折叠已有一次正式真实 UI 样本（低于 130 MiB target 和 150 MiB gate）；扩展/滚动样本及重复性测试仍未完成。
- 具体采样数据和环境见 [`benchmark.md`](benchmark.md)。

## 基线与发布产物

- Phase 0 基线提交：`779e8db91ae9e419c980434247d8653c20eedaf2`（`chore: establish Phase 0 baseline`）。
- `flutter build windows --release`：成功，构建耗时约 29.5 s。
- Release 可执行文件：`build/windows/x64/runner/Release/litetodo.exe`。
- 便携包：`build/artifacts/LiteTodo-1.0.0-windows-x64.zip`（构建完成后生成；无安装器）。
- 干净隔离数据目录验证：首次启动写入 schema v2、revision 0 的空数据，groups/projects/todos/trash 均为 0，不再注入示例 Todo。

## 已完成

### Phase 0 — 桌面基础与性能样本

- 单 Flutter Window/Engine，复用 Full、Compact、QuickAdd 三种窗口模式。
- 50 Todo 与 1000 Todo 基准夹具、Release 运行采样和单实例基础验证。
- 性能门槛的未完成项保留在“当前状态”和“已知未完成”中，未被后续功能结果掩盖。

### Phase 1 — 领域模型与持久化

- schema v2、revision、扁平 `parentId` Todo 树、组/项目/Todo/回收站模型。
- 最大深度 6、循环与非法移动防护、完成状态传播、统计所需时间字段。
- 安全写入（临时文件、flush、回读校验、`data.prev.json`、备份目录）、串行写入和异常恢复链路。
- v1 迁移备份、路径/符号链接防护及干净首次启动空数据。

### Phase 2–3 — 工作区与树交互

- 首页、侧栏、分组/项目增删改、Todo 创建/编辑/完成/移动、拖拽 Before/Inside/After。
- 撤销/重做（最多 50 条，失败 flush 可恢复 redo）、懒加载列表、键盘快捷操作和 QuickAdd 目标项目。
- 回收站的 Todo/项目恢复、清空确认和撤销。

### Phase 4 — Windows 集成与数据工具

- 窗口位置/尺寸持久化、可见区域修正、置顶、紧凑模式、启动隐藏、重置回滚。
- 系统托盘固定 9 项菜单、开机启动、全局快捷键、单实例参数转发和退出顺序（flush → 注销快捷键 → tray dispose → destroy）。
- JSON 导入/导出、UTF-8/schema/reference/cycle/depth 校验、事务式导入回滚、导出临时文件回读校验。
- 设置页的数据、主题、字体、窗口、托盘、关于/许可证入口；设置状态由 `SettingsController` 统一协调。

### Phase 5 — 视觉与统计

- `真实UI` 参考图驱动的首页、设置页、统计页响应式布局；覆盖 1672、860、680 宽度样本。
- UI/system/action 图标统一 `AppIcons` → `lucide_icons_flutter`；项目图标统一本地 IconPark Outline SVG → `ProjectIcons`，无第二套系统图标。
- 统计时间范围、创建 cohort/完成时间语义、日报/项目统计、7×24 热力图和空数据态。
- 关于页版本 `1.0.0+1`、许可证详情懒加载、数据恢复提示和窗口行为提示。

## 依赖

依赖版本以根目录 [`pubspec.yaml`](../pubspec.yaml) 和锁文件为准：

| 依赖 | 版本约束 | 用途 |
|---|---:|---|
| `shadcn_ui` | `^0.56.1` | 桌面 UI 组件和视觉系统 |
| `lucide_icons_flutter` | `^3.1.15` | 统一功能/系统/操作图标 |
| `flutter_svg` | `^2.3.0` | 本地 IconPark SVG 渲染 |
| `window_manager` | `^0.5.2` | 单窗口尺寸、位置和模式切换 |
| `tray_manager` | `^0.5.3` | Windows 系统托盘 |
| `launch_at_startup` | `^0.5.1` | 开机启动 |
| `hotkey_manager` | `^0.2.3` | 全局 QuickAdd 快捷键 |
| `path_provider` | `^2.1.6` | 平台数据目录解析 |
| `file_selector` | `^1.1.0` | 官方本地导入/导出对话框 |
| `screen_retriever` | `^0.2.2` | 屏幕可见区域和窗口边界 |
| `windows_single_instance` | `^1.1.0` | Windows 单实例 |
| `flutter_lints` | `^6.0.0` | Dart/Flutter lint 基线 |

## 验证记录

在 Windows x64 Release 环境完成：

```text
flutter analyze: No issues found
flutter test --concurrency=1: 226/226 passed (约 65 s)
flutter build windows --release: success (约 29.5 s)
```

定向测试覆盖持久化恢复、迁移、树算法、撤销重做、数据传输、窗口/托盘/快捷键、图标策略、响应式页面、统计 cohort 和干净首次启动。Release smoke 还验证了单实例（普通启动与 `--quick-add`）及真实窗口尺寸。

## 已知未完成与风险

- 50 Todo Working Set 仍高于 Phase 0 的 120 MiB gate；在性能调查或正式豁免前，不应把该门槛标记为通过。
- 1000 Todo 扩展/滚动样本尚未执行，默认折叠样本也缺少重复性矩阵。
- 部分桌面稳定性项目（托盘点击、睡眠/唤醒、Explorer 重启、显示器热插拔等）没有完成正式 Release 次数矩阵；现有假控制器/单次 smoke 不能替代它们。
- 统计页的自定义日期服务已具备，但当前 UI 入口保持禁用，避免在没有日期选择器交互验收前伪装成可用功能。
- 发布形态为 Windows x64 便携 ZIP，没有安装器；首次启动会在指定数据目录生成本地文件。

## 后续建议

1. 补齐 1000 Todo 展开/滚动和稳定性矩阵，并复测 50 Todo 内存。
2. 记录性能门槛的调查结论或获得明确豁免后，再关闭 Phase 0 风险。
3. 若开放统计自定义范围，再补日期选择器、键盘/无障碍和跨时区验收。
