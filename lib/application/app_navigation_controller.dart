import 'package:flutter/foundation.dart';

/// The pages available inside the full application frame.
///
/// Page selection deliberately lives outside [WindowController].  Quick Add
/// and Compact are presentations of the same window and must not reset the
/// page selected in the full frame.
enum AppPage { home, statistics, trash, settings }

class AppNavigationController extends ChangeNotifier {
  AppNavigationController({AppPage initialPage = AppPage.home})
    : _page = initialPage;

  AppPage _page;

  AppPage get page => _page;

  void select(AppPage page) {
    if (_page == page) return;
    _page = page;
    notifyListeners();
  }

  void selectPage(AppPage page) => select(page);

  void goHome() => select(AppPage.home);

  void goStatistics() => select(AppPage.statistics);

  void goTrash() => select(AppPage.trash);

  void goSettings() => select(AppPage.settings);
}
