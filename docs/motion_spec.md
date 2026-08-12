# LiteTodo Motion Spec

LiteTodo 的 motion 风格定义为：

```text
Fast
Subtle
Predictable
Desktop-oriented
```

中文口径：

```text
快
轻
稳
几乎察觉不到
```

## Token

统一入口：`lib/app/theme/app_motion.dart`

```text
instant: 80ms
fast: 100ms
normal: 140ms
dialogEnter: 160ms
dialogExit: 110ms
dialogBarrier: 120ms
popoverEnter: 110ms
popoverExit: 80ms
tree: 160ms
page: 140ms
theme: 220ms
completion: 120ms

enterCurve: easeOutCubic
exitCurve: easeInCubic
standardCurve: easeInOutCubic
```

业务组件禁止直接新增随机时长或弹性曲线，例如：

```text
Duration(milliseconds: 173)
Duration(milliseconds: 250)
Curves.bounceOut
Curves.elasticOut
```

保存防抖、文件写入、窗口几何保存等非 UI motion 不受此限制。

## Dialog

统一入口：`lib/presentation/common/app_dialog.dart`

所有 LiteTodo 产品弹窗优先使用 `showAppDialog`，不要直接调用 `showShadDialog`。

Enter：

```text
Opacity: 0 -> 1
Scale: 0.985 -> 1.0
Translate Y: 6px -> 0px
Duration: 160ms
Curve: easeOutCubic
Barrier: 0x26000000
```

Exit：

```text
Opacity: 1 -> 0
Scale: 1.0 -> 0.99
Translate Y: 0px -> 4px
Duration: 110ms
Curve: easeInCubic
```

禁止：

```text
Scale 0 -> 1
Scale 0.8 -> 1
Scale 0.9 -> 1
rotation
bounce
spring
elastic
large slide
```

## Tooltip

Tooltip 只允许 fade：

```text
Opacity only
80ms
```

不要 scale，不要 slide。

## Popover / Menu

Popover、下拉、轻菜单：

```text
Enter: opacity + scale 0.98 -> 1 + Y 4px -> 0, 110ms
Exit: 80ms
Curve: enter easeOutCubic, exit easeInCubic
```

未来若接入显式 anchor，应让 transform origin 靠近触发按钮。

## Todo Tree

树形列表继续使用：

```text
VisibleTodoRow[]
ListView.builder
```

Chevron：

```text
0deg -> 90deg
160ms
easeOutCubic
```

禁止对子 Todo 做逐条 stagger / fade / slide。大量子任务展开时，性能优先。

## Todo Completion

Checkbox：

```text
fill / border: 120ms
icon: fade + very small scale, 100ms
```

Title：

```text
foreground -> muted
line-through appears
120ms
```

完成 Todo 仍留在列表，不做飞走、collapse、大幅位移或 bounce。

## Page / Mode

Full Shell 页面：

```text
只切 Main Content
Opacity 0 -> 1
Translate Y about 4px -> 0
140ms
```

Sidebar、TitleBar、Topbar 保持静止。

Full / Compact / QuickAdd：

```text
Flutter 内容只做 140ms fade
Window bounds 调整仍由 WindowController 控制
不做整窗 scale
```

## Theme

主题切换：

```text
ShadAnimatedTheme
220ms
easeInOutCubic
```

不要为每个 Widget 创建独立 Theme AnimationController。

## Performance

禁止在动画过程中引入：

```text
BackdropFilter blur animation
Clip.antiAliasWithSaveLayer
complex large-area animated Shadow
whole Workspace rebuild from animation tick
one AnimationController per Todo
runtime SVG decode
runtime JSON read/write
recursive full tree widget build
```

AnimatedBuilder 如后续引入，静态 subtree 必须走 `child` 参数。
