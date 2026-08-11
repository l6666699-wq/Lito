import 'package:flutter/foundation.dart';

/// Coordinates composer requests that originate outside the home route.
///
/// The topbar is part of the full shell while the inline composer belongs to
/// HomePage. Keeping the request as a small listenable bridge lets the shell
/// switch back to Home without coupling it to HomePage's private state, and it
/// deliberately does not touch `WindowController` or Quick Add.
class HomePageController extends ChangeNotifier {
  HomePageComposerRequest? _pendingComposerRequest;

  void requestComposer({String? parentId}) {
    _pendingComposerRequest = HomePageComposerRequest(parentId: parentId);
    notifyListeners();
  }

  /// Alias used by shell actions that read as an imperative open command.
  void openComposer({String? parentId}) {
    requestComposer(parentId: parentId);
  }

  HomePageComposerRequest? takeComposerRequest() {
    final request = _pendingComposerRequest;
    _pendingComposerRequest = null;
    return request;
  }
}

class HomePageComposerRequest {
  const HomePageComposerRequest({this.parentId});

  final String? parentId;
}
