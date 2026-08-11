import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Stable semantic names for UI and system affordances.
///
/// Presentation code must depend on this catalog rather than selecting a
/// Lucide glyph directly.  Keeping the mapping here lets us adjust the visual
/// glyph without changing persisted data or every widget call site.
abstract final class AppIcons {
  AppIcons._();

  static const IconData search = LucideIcons.search;
  static const IconData add = LucideIcons.plus;
  static const IconData delete = LucideIcons.trash2;
  static const IconData trash = LucideIcons.trash2;
  static const IconData restore = LucideIcons.rotateCcw;
  static const IconData edit = LucideIcons.pencil;
  static const IconData settings = LucideIcons.settings;
  static const IconData statistics = LucideIcons.chartNoAxesColumn;
  static const IconData theme = LucideIcons.moon;
  static const IconData palette = LucideIcons.palette;
  // Settings keeps these role-specific aliases separate from shell/window
  // controls so visual updates do not change existing product surfaces.
  static const IconData appearance = LucideIcons.palette;
  static const IconData windowSettings = LucideIcons.panelsTopLeft;
  static const IconData about = LucideIcons.circleHelp;
  static const IconData monitor = LucideIcons.monitor;
  static const IconData download = LucideIcons.download;
  static const IconData keyboard = LucideIcons.keyboard;
  static const IconData hotkeyEdit = LucideIcons.pencil;
  static const IconData inbox = LucideIcons.inbox;
  static const IconData today = LucideIcons.calendarDays;
  static const IconData recent = LucideIcons.clock3;
  static const IconData completed = LucideIcons.circleCheck;
  static const IconData archive = LucideIcons.archive;
  static const IconData expand = LucideIcons.chevronsDown;
  static const IconData collapse = LucideIcons.chevronsUp;
  static const IconData more = LucideIcons.ellipsis;
  static const IconData filter = LucideIcons.funnel;
  static const IconData sort = LucideIcons.arrowUpDown;
  static const IconData shortcut = LucideIcons.keyboard;
  static const IconData font = LucideIcons.type;
  static const IconData folder = LucideIcons.folder;
  static const IconData backup = LucideIcons.databaseBackup;
  static const IconData exportData = LucideIcons.download;
  static const IconData importData = LucideIcons.upload;
  static const IconData tray = LucideIcons.panelBottom;
  static const IconData windowMinimize = LucideIcons.minus;
  static const IconData windowMaximize = LucideIcons.square;
  static const IconData windowClose = LucideIcons.x;
  static const IconData info = LucideIcons.info;
  static const IconData notification = LucideIcons.bell;
  static const IconData clock = LucideIcons.clock;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData check = LucideIcons.check;
  static const IconData minus = LucideIcons.minus;
  static const IconData dragHandle = LucideIcons.gripVertical;
  static const IconData layers = LucideIcons.layers;
  static const IconData star = LucideIcons.star;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData lock = LucideIcons.lock;
  static const IconData pin = LucideIcons.pin;
  static const IconData compact = LucideIcons.panelTop;
  static const IconData quickAdd = LucideIcons.zap;
  static const IconData stickyNotes = LucideIcons.notebookPen;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData fullscreen = LucideIcons.maximize2;
}
