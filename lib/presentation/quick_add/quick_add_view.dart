import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/quick_add_controller.dart';
import '../../icons/local_project_icon.dart';

class _QuickAddCancelIntent extends Intent {
  const _QuickAddCancelIntent();
}

class QuickAddView extends StatefulWidget {
  const QuickAddView({super.key, required this.controller});

  final QuickAddController controller;

  @override
  State<QuickAddView> createState() => _QuickAddViewState();
}

class _QuickAddViewState extends State<QuickAddView> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.draft);
    _focusNode = FocusNode(debugLabel: 'quick-add-input');
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || _textController.text == widget.controller.draft) return;
    _textController.value = TextEditingValue(
      text: widget.controller.draft,
      selection: TextSelection.collapsed(
        offset: widget.controller.draft.length,
      ),
    );
  }

  Future<void> _submit() async {
    await widget.controller.submit(_textController.text);
    if (mounted && widget.controller.error == null) {
      _textController.clear();
    }
  }

  void _cancelFromKeyboard() {
    unawaited(widget.controller.cancel());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.canvas,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            unawaited(widget.controller.cancel());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Padding(
          padding: const EdgeInsets.all(AppMetrics.compactPadding),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, child) => Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.focusSoft,
                        borderRadius: BorderRadius.circular(
                          AppMetrics.smallRadius,
                        ),
                      ),
                      child: LocalProjectIcon(
                        iconKey: 'add',
                        color: colors.focus,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Shortcuts(
                        shortcuts: const <ShortcutActivator, Intent>{
                          SingleActivator(LogicalKeyboardKey.escape):
                              _QuickAddCancelIntent(),
                        },
                        child: Actions(
                          actions: <Type, Action<Intent>>{
                            _QuickAddCancelIntent:
                                CallbackAction<_QuickAddCancelIntent>(
                                  onInvoke: (_) {
                                    _cancelFromKeyboard();
                                    return null;
                                  },
                                ),
                          },
                          child: EditableText(
                            controller: _textController,
                            focusNode: _focusNode,
                            autofocus: true,
                            maxLines: 1,
                            textInputAction: TextInputAction.done,
                            onChanged: widget.controller.setDraft,
                            onSubmitted: (_) => _submit(),
                            cursorColor: colors.focus,
                            backgroundCursorColor: colors.textFaint,
                            style: TextStyle(color: colors.text, fontSize: 14),
                            selectionColor: colors.focusSoft,
                            strutStyle: const StrutStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton.ghost(
                      onPressed: widget.controller.isSubmitting
                          ? null
                          : _submit,
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: colors.focus,
                      child: const Text('添加', style: TextStyle(fontSize: 12)),
                    ),
                    ShadButton.ghost(
                      onPressed: widget.controller.cancel,
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: colors.textMuted,
                      child: const Text('Esc', style: TextStyle(fontSize: 11)),
                    ),
                    if (widget.controller.error != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          widget.controller.error!,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
