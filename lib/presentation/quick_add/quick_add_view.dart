import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../app/theme/project_palette.dart';
import '../../application/quick_add_controller.dart';
import '../../icons/app_icons.dart';
import '../../icons/project_icon.dart';

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
          padding: const EdgeInsets.all(AppMetrics.compactPadding / 2),
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
                builder: (context, child) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TargetSelector(controller: widget.controller),
                    const SizedBox(height: 6),
                    _QuickAddEditor(
                      controller: widget.controller,
                      textController: _textController,
                      focusNode: _focusNode,
                      colors: colors,
                      onSubmit: _submit,
                      onCancel: widget.controller.cancel,
                      onCancelFromKeyboard: _cancelFromKeyboard,
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

class _TargetSelector extends StatelessWidget {
  const _TargetSelector({required this.controller});

  final QuickAddController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedTarget;
    final targets = controller.availableTargets;
    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final target in targets)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _TargetChip(
                  target: target,
                  selected: target == selected,
                  onPressed: () => controller.setTarget(target.projectId),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.target,
    required this.selected,
    required this.onPressed,
  });

  final QuickAddTarget target;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final targetColor = ProjectPalette.resolve(target.colorKey).accent;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Quick Add 目标：${target.name}',
      child: ShadButton.ghost(
        key: ValueKey<String>(
          'quick-add-target-${target.projectId ?? 'inbox'}',
        ),
        onPressed: onPressed,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        foregroundColor: selected ? colors.focus : colors.textMuted,
        backgroundColor: selected ? colors.focusSoft : null,
        hoverBackgroundColor: colors.focusSoft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (target.isInbox)
              Icon(AppIcons.inbox, size: 13, color: targetColor)
            else
              ProjectIcon(
                iconKey: target.iconKey,
                color: targetColor,
                size: 13,
              ),
            const SizedBox(width: 4),
            Text(target.name, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _QuickAddEditor extends StatelessWidget {
  const _QuickAddEditor({
    required this.controller,
    required this.textController,
    required this.focusNode,
    required this.colors,
    required this.onSubmit,
    required this.onCancel,
    required this.onCancelFromKeyboard,
  });

  final QuickAddController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final AppColorScheme colors;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onCancel;
  final VoidCallback onCancelFromKeyboard;

  @override
  Widget build(BuildContext context) {
    final input = Expanded(
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): _QuickAddCancelIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _QuickAddCancelIntent: CallbackAction<_QuickAddCancelIntent>(
              onInvoke: (_) {
                onCancelFromKeyboard();
                return null;
              },
            ),
          },
          child: EditableText(
            controller: textController,
            focusNode: focusNode,
            autofocus: true,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onChanged: controller.setDraft,
            onSubmitted: (_) => onSubmit(),
            cursorColor: colors.focus,
            backgroundCursorColor: colors.textFaint,
            style: TextStyle(color: colors.text, fontSize: 14),
            selectionColor: colors.focusSoft,
            strutStyle: const StrutStyle(fontSize: 14),
          ),
        ),
      ),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadButton.ghost(
          onPressed: controller.isSubmitting ? null : onSubmit,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: colors.focus,
          child: const Text('添加', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: AppMetrics.unit),
        ShadButton.ghost(
          onPressed: onCancel,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: colors.textMuted,
          child: const Text('Esc', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
    final error = controller.error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              controller.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          );

    final editorRow = Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.focusSoft,
            borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
          ),
          child: Icon(AppIcons.add, color: colors.focus, size: 16),
        ),
        const SizedBox(width: 10),
        input,
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        editorRow,
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (controller.error != null) Flexible(child: error),
            controls,
          ],
        ),
      ],
    );
  }
}
