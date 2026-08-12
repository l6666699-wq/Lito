# LiteTodo

LiteTodo 是一款适合 Windows 桌面使用的本地待办工具。它把任务整理成项目、分组和树形清单，让你可以把一件大事拆成多层小任务，并且不用注册账号、不依赖服务器，数据保存在自己的电脑里。

它适合这些场景：

- 个人日程、学习计划、工作任务、项目拆解。
- 想要一个轻量工具，但又不想把待办事项同步到云端。
- 喜欢用树形结构整理任务，而不是只写一长串清单。
- 需要快速记录临时想法，再回到完整窗口慢慢整理。

## 你可以用它做什么

- **按项目管理任务**：把不同事情分到不同项目里，避免所有待办混在一起。
- **拆分多级任务**：每个 Todo 都可以继续拆成子任务，最多支持 6 层。
- **快速添加待办**：通过 QuickAdd 模式快速记下一条任务，不打断当前工作。
- **整理和恢复**：支持拖拽移动、撤销/重做、回收站恢复和清空确认。
- **本地备份数据**：支持导入、导出、备份和异常恢复，方便迁移或留档。
- **贴合桌面使用**：支持窗口置顶、紧凑模式、系统托盘、全局快捷键和开机启动。
- **查看任务统计**：通过统计页了解任务完成情况和近期节奏。

## 项目截图

目前仓库还没有放入运行截图。想在 README 中展示项目运行图片时，推荐这样做：

1. 运行 LiteTodo，截取首页、快速添加、设置页或统计页等关键画面。
2. 在项目里新建图片目录，例如 `docs/images/`。
3. 把截图放进去，建议使用英文文件名，例如：

```text
docs/images/home.png
docs/images/quick-add.png
docs/images/settings.png
```

4. 在 README 的“项目截图”下面加入 Markdown 图片语法：

```md
![LiteTodo 首页](docs/images/home.png)
![QuickAdd 快速添加](docs/images/quick-add.png)
![设置页](docs/images/settings.png)
```

如果图片已经上传到 GitHub，使用这种相对路径就可以正常显示。建议截图宽度保持在 1200px 到 1600px 左右，既清晰，也不会让仓库变得太大。

## 如何开始使用

LiteTodo 目前面向 Windows 10/11 x64。项目产物是便携版应用，不需要安装器。

如果你已经拿到了发布包：

1. 解压 `LiteTodo-1.0.0-windows-x64.zip`。
2. 打开解压后的目录。
3. 双击运行 `litetodo.exe`。

如果你是从源码运行，请先安装 Flutter stable，然后执行：

```bash
flutter pub get
flutter run -d windows
```

构建 Windows 便携版：

```bash
flutter build windows --release
```

构建完成后，可执行文件位于：

```text
build/windows/x64/runner/Release/litetodo.exe
```

发布时可以把 `build/windows/x64/runner/Release` 整个目录压缩成 ZIP，上传到 GitHub Releases，方便其他人下载使用。

## 数据和隐私

LiteTodo 是本地优先应用：

- 不需要登录账号。
- 不依赖服务器或网络服务。
- 待办、项目、设置、备份和日志都保存在本机。
- 默认使用系统应用数据目录。

如果你想指定数据保存位置，可以通过 `LITETODO_DATA_DIR` 设置数据目录：

```powershell
$env:LITETODO_DATA_DIR = "D:\LiteTodoData"
flutter run -d windows
```

常见数据文件包括：

```text
data.json
settings.json
data.prev.json
backups/
logs/
```

## 适合谁

LiteTodo 更适合个人使用，而不是团队协作平台。它不做账号、云同步、多人共享、复杂提醒或移动端同步，重点是让你在自己的 Windows 电脑上稳定、快速地管理任务。

## 开发者说明

常用检查命令：

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
```

核心约束：

- Flutter Desktop，优先支持 Windows 10/11 x64。
- 单 Flutter 窗口复用 Full、Compact、QuickAdd 三种模式。
- 数据使用本地 JSON 文件保存。
- 不引入账号、服务端、数据库或云同步。

更多开发记录见：

- [开发进度](docs/progress.md)
- [项目定稿开发文档](docs/LiteTodo_Flutter_项目定稿开发文档.md)
- [第三方许可说明](THIRD_PARTY_NOTICES.md)
