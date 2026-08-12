# LiteTodo

[中文](README.md) | **English**

### A simple, lightweight, local-first Todo app for Windows desktop

**Break complex work into simple steps, and keep all your Todos on your own computer.**

Project management · Nested tasks · QuickAdd · Compact mode · Local storage · Data backup

![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?logo=windows&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-Desktop-02569B?logo=flutter&logoColor=white)
![Local First](https://img.shields.io/badge/Data-Local%20First-2EA043)
![License](https://img.shields.io/badge/License-See%20Repository-lightgrey)

------

## About LiteTodo

LiteTodo is a local Todo app designed for **Windows desktop**.

It has no account system, no cloud sync, and no server dependency.

You can organize tasks as **Project -> Todo -> Subtask**, using a tree structure for study plans, work tasks, personal projects, and everyday plans.

All data is saved on your own computer by default.

> **LiteTodo is not trying to become another complicated task management platform. It is a desktop tool that opens quickly, helps you capture work, and stays out of your way.**

------

## Screenshots

![LiteTodo home](docs/images/home.png)

![QuickAdd](docs/images/quick-add.png)

![Settings](docs/images/settings.png)

------

## Why LiteTodo?

Many Todo apps slowly turn into:

accounts, teams, subscriptions, cloud sync, calendars, chats, AI, notification centers...

Then someone who only wanted to write down "submit homework tomorrow" somehow ends up inside a full enterprise collaboration suite.

LiteTodo takes a different path.

### Break Tasks Down With A Tree

A complex thing is usually not a single Todo.

In LiteTodo, every task can have subtasks, up to **6 levels** deep.

```text
Ship the next version
├─ Finish home page
│  ├─ Adjust task list
│  └─ Improve empty state
├─ Finish settings page
│  ├─ Theme settings
│  └─ Font settings
└─ Release
   ├─ Release build
   └─ GitHub Release
```

You do not have to squeeze everything into one long flat list.

------

### QuickAdd, Capture Without Breaking Focus

When an idea or task appears, you do not need to open the full main window.

Use **QuickAdd** to capture it quickly:

```text
Press shortcut
↓
Type task
↓
Enter
↓
Return to work
```

It reduces the interruption caused by recording a Todo.

------

### Designed For Desktop Use

LiteTodo is not a web page wrapped as a desktop task list. It is designed around real Windows desktop usage.

It supports:

- Full mode
- Compact mode
- QuickAdd mode
- Always on top
- System tray
- Global shortcut
- Launch at startup

You can use it as a regular app, or let it sit quietly at the edge of your desktop.

------

### Local First

LiteTodo does not send your tasks to any server by default.

```text
Your tasks
   ↓
LiteTodo
   ↓
Local JSON files
```

No:

- Account registration
- Cloud database
- Backend server
- Required internet connection
- User behavior upload
- Team collaboration system

Your data belongs to you, not to an account.

------

### Portable Data

Local storage does not mean your data is trapped on one machine.

LiteTodo supports:

- Data export
- Data import
- Automatic backup
- Previous data recovery
- Crash recovery
- Custom data directory

When changing computers or reinstalling Windows, you can migrate your own data directly.

------

## Core Features

| Feature | Description |
| --- | --- |
| Project management | Manage work, study, and personal plans separately |
| Nested tasks | Todo items support up to 6 levels of subtasks |
| Drag to organize | Adjust task order and hierarchy |
| QuickAdd | Capture temporary tasks quickly |
| Undo / redo | Reduce the cost of mistakes |
| Trash | Restore deleted tasks |
| Statistics | Review completed tasks and recent progress |
| Always on top | Keep your task list visible while working |
| Compact mode | Show current tasks in a smaller window |
| Global shortcut | Open capture without switching apps |
| Launch at startup | Start automatically after Windows login |
| Local backup | Save and recover important data |
| Import / export | Move or archive your data easily |
| Personal settings | Customize theme color and font settings |

------

## Who Is LiteTodo For?

### Study

Break a long-term goal into small tasks you can actually finish each day.

```text
Prepare for exam
├─ Math
│  ├─ Chapter 1
│  └─ Chapter 2
├─ English
│  ├─ Vocabulary
│  └─ Reading
└─ Politics
```

### Development / Work

Break a feature into design, development, testing, and release work.

```text
User login
├─ UI
├─ API
├─ State management
├─ Error handling
└─ Tests
```

### Personal Plans

Travel, renovation, shopping, reading plans, long-term goals...

Anything that can be broken down can become a task tree.

------

## Getting Started

### System Requirements

Currently supported first:

```text
Windows 10 x64
Windows 11 x64
```

------

### Use A Release Build

LiteTodo is published as a **portable** app. No installer is required.

After downloading a release:

```text
LiteTodo-x.x.x-windows-x64.zip
```

Extract it, then run:

```text
litetodo.exe
```

That is all.

No registration.

No server setup.

No database setup.

------

## Where Is Data Stored?

LiteTodo uses the Windows app data directory by default.

Main files include:

```text
data.json
settings.json
data.prev.json

backups/
logs/
```

Meaning:

- `data.json`: projects and tasks
- `settings.json`: app settings
- `data.prev.json`: previous data snapshot
- `backups/`: automatic backups
- `logs/`: runtime logs

------

## Custom Data Directory

If you want to save data in a specific directory, set:

```powershell
$env:LITETODO_DATA_DIR = "D:\LiteTodoData"
```

Then run LiteTodo.

Development example:

```powershell
$env:LITETODO_DATA_DIR = "D:\LiteTodoData"
flutter run -d windows
```

This also means you can place the data directory at:

```text
D:\LiteTodoData
```

or inside your own sync drive folder.

LiteTodo itself still does not provide cloud sync.

------

## Privacy

LiteTodo is a **Local First** app.

By default:

**LiteTodo does not need to know who you are, and it does not need to know what you write.**

Your:

- Todos
- Projects
- Settings
- Backups
- Logs

are stored locally.

The project will not upload your Todo content to a remote server just because it is convenient for analytics. There is already enough software doing that.

------

## Tech Stack

LiteTodo is built with Flutter Desktop.

```text
Flutter
├─ Windows Desktop
├─ Vue?      no
├─ Electron? no
└─ Server?   no
```

Core technical direction:

- Flutter Desktop
- Dart
- Windows native desktop
- Local JSON data storage
- Single window with multiple modes
- Local backup and recovery

The app modes:

```text
Full
Compact
QuickAdd
```

are not three separate apps. They reuse the same Flutter desktop window.

------

## Run From Source

Install first:

```text
Flutter Stable
Windows Desktop Development Environment
Visual Studio C++ Desktop Development Tools
```

After cloning the project, run:

```bash
flutter pub get
```

Start the Windows version:

```bash
flutter run -d windows
```

------

## Build Windows Release

Run:

```bash
flutter build windows --release
```

The build output is:

```text
build/windows/x64/runner/Release/
```

Main executable:

```text
build/windows/x64/runner/Release/litetodo.exe
```

When publishing, package the whole:

```text
Release/
```

directory, not only `litetodo.exe`.

For example:

```text
LiteTodo-0.0.1-windows-x64.zip
```

Then upload it to GitHub Releases.

------

## Development Checks

Before committing code, it is recommended to run:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
```

Expected result:

```text
Format OK
Analyze OK
Test OK
```

------

## Project Principles

LiteTodo tries to follow a few principles.

### 1. Local First

Task data belongs first to the user's own computer.

### 2. Simplicity First

If something can be done with one clear action, it should not need three layers of dialogs.

### 3. Desktop First

Mouse, keyboard, shortcuts, and window behavior matter.

### 4. Data Safety First

When changing data structures, consider:

```text
Migration
Backup
Rollback
Recovery
```

instead of saying:

> It should be fine.

### 5. Do Not Add Features Just For Count

LiteTodo is not trying to win by having the longest feature list.

What really matters is:

> **Open fast. Capture fast. Organize comfortably.**

------

## What LiteTodo Does Not Plan To Become

At least for now, LiteTodo does not plan to become:

- Team collaboration platform
- Enterprise project management system
- Chat app
- Cloud notes platform
- Social app
- Shared multi-user Todo app
- Mandatory account system
- Subscription SaaS

It is first:

> **A Windows desktop Todo that belongs to you.**

------

## Project Docs

More development documents:

- [Development progress](docs/progress.md)
- [LiteTodo Flutter final development document](docs/LiteTodo_Flutter_项目定稿开发文档.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

------

## LiteTodo

**Less cloud. Less noise. More done.**

A little simpler.

A little more focused.

Get things done.
