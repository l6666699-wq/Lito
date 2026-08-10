import 'project_icon_entry.dart';

/// Local-only IconPark catalog. Persisted projects store only
/// [ProjectIconEntry.key] and never a URL or renderer-specific value.
abstract final class ProjectIcons {
  ProjectIcons._();

  static const String fallbackKey = 'folder';

  static const List<ProjectIconEntry> entries = <ProjectIconEntry>[
    ProjectIconEntry(key: 'add', assetPath: 'assets/icons/iconpark/add.svg'),
    ProjectIconEntry(
      key: 'alert',
      assetPath: 'assets/icons/iconpark/alert.svg',
    ),
    ProjectIconEntry(key: 'book', assetPath: 'assets/icons/iconpark/book.svg'),
    ProjectIconEntry(
      key: 'bookmark',
      assetPath: 'assets/icons/iconpark/bookmark.svg',
    ),
    ProjectIconEntry(
      key: 'calendar',
      assetPath: 'assets/icons/iconpark/calendar.svg',
    ),
    ProjectIconEntry(
      key: 'camera',
      assetPath: 'assets/icons/iconpark/camera.svg',
    ),
    ProjectIconEntry(
      key: 'check',
      assetPath: 'assets/icons/iconpark/check.svg',
    ),
    ProjectIconEntry(
      key: 'check_correct',
      assetPath: 'assets/icons/iconpark/check_correct.svg',
    ),
    ProjectIconEntry(
      key: 'checklist',
      assetPath: 'assets/icons/iconpark/checklist.svg',
    ),
    ProjectIconEntry(key: 'code', assetPath: 'assets/icons/iconpark/code.svg'),
    ProjectIconEntry(
      key: 'code_computer',
      assetPath: 'assets/icons/iconpark/code_computer.svg',
    ),
    ProjectIconEntry(
      key: 'dashboard',
      assetPath: 'assets/icons/iconpark/dashboard.svg',
    ),
    ProjectIconEntry(key: 'data', assetPath: 'assets/icons/iconpark/data.svg'),
    ProjectIconEntry(
      key: 'document_folder',
      assetPath: 'assets/icons/iconpark/document_folder.svg',
    ),
    ProjectIconEntry(key: 'edit', assetPath: 'assets/icons/iconpark/edit.svg'),
    ProjectIconEntry(
      key: 'file_addition',
      assetPath: 'assets/icons/iconpark/file_addition.svg',
    ),
    ProjectIconEntry(key: 'flag', assetPath: 'assets/icons/iconpark/flag.svg'),
    ProjectIconEntry(
      key: 'folder',
      assetPath: 'assets/icons/iconpark/folder.svg',
    ),
    ProjectIconEntry(
      key: 'folder_code',
      assetPath: 'assets/icons/iconpark/folder_code.svg',
    ),
    ProjectIconEntry(
      key: 'folder_open',
      assetPath: 'assets/icons/iconpark/folder_open.svg',
    ),
    ProjectIconEntry(
      key: 'folder_plus',
      assetPath: 'assets/icons/iconpark/folder_plus.svg',
    ),
    ProjectIconEntry(key: 'gear', assetPath: 'assets/icons/iconpark/gear.svg'),
    ProjectIconEntry(key: 'gift', assetPath: 'assets/icons/iconpark/gift.svg'),
    ProjectIconEntry(
      key: 'heart',
      assetPath: 'assets/icons/iconpark/heart.svg',
    ),
    ProjectIconEntry(key: 'home', assetPath: 'assets/icons/iconpark/home.svg'),
    ProjectIconEntry(
      key: 'inbox',
      assetPath: 'assets/icons/iconpark/inbox.svg',
    ),
    ProjectIconEntry(key: 'idea', assetPath: 'assets/icons/iconpark/idea.svg'),
    ProjectIconEntry(key: 'list', assetPath: 'assets/icons/iconpark/list.svg'),
    ProjectIconEntry(
      key: 'list_checkbox',
      assetPath: 'assets/icons/iconpark/list_checkbox.svg',
    ),
    ProjectIconEntry(
      key: 'list_view',
      assetPath: 'assets/icons/iconpark/list_view.svg',
    ),
    ProjectIconEntry(
      key: 'light',
      assetPath: 'assets/icons/iconpark/light.svg',
    ),
    ProjectIconEntry(key: 'lock', assetPath: 'assets/icons/iconpark/lock.svg'),
    ProjectIconEntry(
      key: 'message',
      assetPath: 'assets/icons/iconpark/message.svg',
    ),
    ProjectIconEntry(
      key: 'mindmap_list',
      assetPath: 'assets/icons/iconpark/mindmap_list.svg',
    ),
    ProjectIconEntry(key: 'more', assetPath: 'assets/icons/iconpark/more.svg'),
    ProjectIconEntry(
      key: 'notes',
      assetPath: 'assets/icons/iconpark/notes.svg',
    ),
    ProjectIconEntry(key: 'plan', assetPath: 'assets/icons/iconpark/plan.svg'),
    ProjectIconEntry(
      key: 'puzzle',
      assetPath: 'assets/icons/iconpark/puzzle.svg',
    ),
    ProjectIconEntry(
      key: 'rocket',
      assetPath: 'assets/icons/iconpark/rocket.svg',
    ),
    ProjectIconEntry(
      key: 'search',
      assetPath: 'assets/icons/iconpark/search.svg',
    ),
    ProjectIconEntry(
      key: 'setting',
      assetPath: 'assets/icons/iconpark/setting.svg',
    ),
    ProjectIconEntry(key: 'star', assetPath: 'assets/icons/iconpark/star.svg'),
    ProjectIconEntry(
      key: 'sparkles',
      assetPath: 'assets/icons/iconpark/sparkles.svg',
    ),
    ProjectIconEntry(
      key: 'target',
      assetPath: 'assets/icons/iconpark/target.svg',
    ),
    ProjectIconEntry(key: 'time', assetPath: 'assets/icons/iconpark/time.svg'),
    ProjectIconEntry(
      key: 'todo_list',
      assetPath: 'assets/icons/iconpark/todo_list.svg',
    ),
    ProjectIconEntry(key: 'tool', assetPath: 'assets/icons/iconpark/tool.svg'),
    ProjectIconEntry(
      key: 'tree_list',
      assetPath: 'assets/icons/iconpark/tree_list.svg',
    ),
    ProjectIconEntry(
      key: 'trophy',
      assetPath: 'assets/icons/iconpark/trophy.svg',
    ),
    ProjectIconEntry(key: 'user', assetPath: 'assets/icons/iconpark/user.svg'),
    ProjectIconEntry(
      key: 'workbench',
      assetPath: 'assets/icons/iconpark/workbench.svg',
    ),
    ProjectIconEntry(
      key: 'world',
      assetPath: 'assets/icons/iconpark/world.svg',
    ),
    ProjectIconEntry(
      key: 'write',
      assetPath: 'assets/icons/iconpark/write.svg',
    ),
    ProjectIconEntry(
      key: 'check_one',
      assetPath: 'assets/icons/iconpark/check_one.svg',
    ),
    ProjectIconEntry(
      key: 'delete',
      assetPath: 'assets/icons/iconpark/delete.svg',
    ),
    ProjectIconEntry(
      key: 'download',
      assetPath: 'assets/icons/iconpark/download.svg',
    ),
    ProjectIconEntry(
      key: 'upload',
      assetPath: 'assets/icons/iconpark/upload.svg',
    ),
  ];

  static final Map<String, ProjectIconEntry> _byKey =
      <String, ProjectIconEntry>{for (final entry in entries) entry.key: entry};

  static ProjectIconEntry get fallback => _byKey[fallbackKey]!;

  static ProjectIconEntry resolve(String key) => _byKey[key] ?? fallback;

  static bool contains(String key) => _byKey.containsKey(key);

  static Iterable<String> get keys => _byKey.keys;
}
