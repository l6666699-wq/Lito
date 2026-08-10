import 'icon_entry.dart';

/// Local-only IconPark catalog.  Persisted projects store only [IconEntry.key]
/// and never a URL or renderer-specific value.
class IconCatalog {
  IconCatalog._();

  static const String fallbackKey = 'folder';

  static const List<IconEntry> entries = <IconEntry>[
    IconEntry(key: 'add', assetPath: 'assets/icons/iconpark/add.svg'),
    IconEntry(key: 'alert', assetPath: 'assets/icons/iconpark/alert.svg'),
    IconEntry(key: 'book', assetPath: 'assets/icons/iconpark/book.svg'),
    IconEntry(key: 'bookmark', assetPath: 'assets/icons/iconpark/bookmark.svg'),
    IconEntry(key: 'calendar', assetPath: 'assets/icons/iconpark/calendar.svg'),
    IconEntry(key: 'camera', assetPath: 'assets/icons/iconpark/camera.svg'),
    IconEntry(key: 'check', assetPath: 'assets/icons/iconpark/check.svg'),
    IconEntry(
      key: 'check_correct',
      assetPath: 'assets/icons/iconpark/check_correct.svg',
    ),
    IconEntry(
      key: 'checklist',
      assetPath: 'assets/icons/iconpark/checklist.svg',
    ),
    IconEntry(key: 'code', assetPath: 'assets/icons/iconpark/code.svg'),
    IconEntry(
      key: 'code_computer',
      assetPath: 'assets/icons/iconpark/code_computer.svg',
    ),
    IconEntry(
      key: 'dashboard',
      assetPath: 'assets/icons/iconpark/dashboard.svg',
    ),
    IconEntry(key: 'data', assetPath: 'assets/icons/iconpark/data.svg'),
    IconEntry(
      key: 'document_folder',
      assetPath: 'assets/icons/iconpark/document_folder.svg',
    ),
    IconEntry(key: 'edit', assetPath: 'assets/icons/iconpark/edit.svg'),
    IconEntry(
      key: 'file_addition',
      assetPath: 'assets/icons/iconpark/file_addition.svg',
    ),
    IconEntry(key: 'flag', assetPath: 'assets/icons/iconpark/flag.svg'),
    IconEntry(key: 'folder', assetPath: 'assets/icons/iconpark/folder.svg'),
    IconEntry(
      key: 'folder_code',
      assetPath: 'assets/icons/iconpark/folder_code.svg',
    ),
    IconEntry(
      key: 'folder_open',
      assetPath: 'assets/icons/iconpark/folder_open.svg',
    ),
    IconEntry(
      key: 'folder_plus',
      assetPath: 'assets/icons/iconpark/folder_plus.svg',
    ),
    IconEntry(key: 'gear', assetPath: 'assets/icons/iconpark/gear.svg'),
    IconEntry(key: 'gift', assetPath: 'assets/icons/iconpark/gift.svg'),
    IconEntry(key: 'heart', assetPath: 'assets/icons/iconpark/heart.svg'),
    IconEntry(key: 'home', assetPath: 'assets/icons/iconpark/home.svg'),
    IconEntry(key: 'inbox', assetPath: 'assets/icons/iconpark/inbox.svg'),
    IconEntry(key: 'idea', assetPath: 'assets/icons/iconpark/idea.svg'),
    IconEntry(key: 'list', assetPath: 'assets/icons/iconpark/list.svg'),
    IconEntry(
      key: 'list_checkbox',
      assetPath: 'assets/icons/iconpark/list_checkbox.svg',
    ),
    IconEntry(
      key: 'list_view',
      assetPath: 'assets/icons/iconpark/list_view.svg',
    ),
    IconEntry(key: 'light', assetPath: 'assets/icons/iconpark/light.svg'),
    IconEntry(key: 'lock', assetPath: 'assets/icons/iconpark/lock.svg'),
    IconEntry(key: 'message', assetPath: 'assets/icons/iconpark/message.svg'),
    IconEntry(
      key: 'mindmap_list',
      assetPath: 'assets/icons/iconpark/mindmap_list.svg',
    ),
    IconEntry(key: 'more', assetPath: 'assets/icons/iconpark/more.svg'),
    IconEntry(key: 'notes', assetPath: 'assets/icons/iconpark/notes.svg'),
    IconEntry(key: 'plan', assetPath: 'assets/icons/iconpark/plan.svg'),
    IconEntry(key: 'puzzle', assetPath: 'assets/icons/iconpark/puzzle.svg'),
    IconEntry(key: 'rocket', assetPath: 'assets/icons/iconpark/rocket.svg'),
    IconEntry(key: 'search', assetPath: 'assets/icons/iconpark/search.svg'),
    IconEntry(key: 'setting', assetPath: 'assets/icons/iconpark/setting.svg'),
    IconEntry(key: 'star', assetPath: 'assets/icons/iconpark/star.svg'),
    IconEntry(key: 'sparkles', assetPath: 'assets/icons/iconpark/sparkles.svg'),
    IconEntry(key: 'target', assetPath: 'assets/icons/iconpark/target.svg'),
    IconEntry(key: 'time', assetPath: 'assets/icons/iconpark/time.svg'),
    IconEntry(
      key: 'todo_list',
      assetPath: 'assets/icons/iconpark/todo_list.svg',
    ),
    IconEntry(key: 'tool', assetPath: 'assets/icons/iconpark/tool.svg'),
    IconEntry(
      key: 'tree_list',
      assetPath: 'assets/icons/iconpark/tree_list.svg',
    ),
    IconEntry(key: 'trophy', assetPath: 'assets/icons/iconpark/trophy.svg'),
    IconEntry(key: 'user', assetPath: 'assets/icons/iconpark/user.svg'),
    IconEntry(
      key: 'workbench',
      assetPath: 'assets/icons/iconpark/workbench.svg',
    ),
    IconEntry(key: 'world', assetPath: 'assets/icons/iconpark/world.svg'),
    IconEntry(key: 'write', assetPath: 'assets/icons/iconpark/write.svg'),
    IconEntry(
      key: 'check_one',
      assetPath: 'assets/icons/iconpark/check_one.svg',
    ),
    IconEntry(key: 'delete', assetPath: 'assets/icons/iconpark/delete.svg'),
    IconEntry(key: 'download', assetPath: 'assets/icons/iconpark/download.svg'),
    IconEntry(key: 'upload', assetPath: 'assets/icons/iconpark/upload.svg'),
  ];

  static final Map<String, IconEntry> _byKey = <String, IconEntry>{
    for (final entry in entries) entry.key: entry,
  };

  static IconEntry resolve(String key) => _byKey[key] ?? _byKey[fallbackKey]!;

  static bool contains(String key) => _byKey.containsKey(key);

  static Iterable<String> get keys => _byKey.keys;
}
