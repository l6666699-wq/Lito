import 'package:flutter/foundation.dart';

/// Coordinates composer requests that originate outside the home route.
///
/// The topbar is part of the full shell while the inline composer belongs to
/// HomePage. Keeping the request as a small listenable bridge lets the shell
/// switch back to Home without coupling it to HomePage's private state, and it
/// deliberately does not touch `WindowController` or Quick Add.
class HomePageController extends ChangeNotifier {
  HomePageComposerRequest? _pendingComposerRequest;

  void requestComposer({
    String? parentId,
    String? projectId,
    String? groupId,
  }) {
    _pendingComposerRequest = HomePageComposerRequest(
      parentId: parentId,
      projectId: projectId,
      groupId: groupId,
    );
    notifyListeners();
  }

  /// Alias used by shell actions that read as an imperative open command.
  void openComposer({String? parentId, String? projectId, String? groupId}) {
    requestComposer(
      parentId: parentId,
      projectId: projectId,
      groupId: groupId,
    );
  }

  HomePageComposerRequest? takeComposerRequest() {
    final request = _pendingComposerRequest;
    _pendingComposerRequest = null;
    return request;
  }
}

class HomePageComposerRequest {
  const HomePageComposerRequest({this.parentId, this.projectId, this.groupId});

  final String? parentId;
  final String? projectId;
  final String? groupId;
}
