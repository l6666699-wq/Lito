import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
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
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, child) {
            final selectedTarget = widget.controller.selectedTarget;
            final accent = _targetAccent(colors, selectedTarget);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.borderStrong),
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF1F2937).withValues(alpha: .10),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      colors.surface,
                      Color.lerp(colors.surface, accent, .025) ??
                          colors.surface,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TargetSelector(
                        controller: widget.controller,
                        accent: accent,
                      ),
                      const SizedBox(height: 14),
                      _QuickAddEditor(
                        controller: widget.controller,
                        textController: _textController,
                        focusNode: _focusNode,
                        colors: colors,
                        accent: accent,
                        onSubmit: _submit,
                        onCancel: widget.controller.cancel,
                        onCancelFromKeyboard: _cancelFromKeyboard,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Color _targetAccent(AppColorScheme colors, QuickAddTarget target) {
  if (!target.isProject) return colors.focus;
  return ProjectPalette.resolve(target.colorKey).accent;
}

class _TargetSelector extends StatelessWidget {
  const _TargetSelector({required this.controller, required this.accent});

  final QuickAddController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedTarget;
    final targets = controller.availableTargets;
    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final target in targets)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _TargetChip(
                  target: target,
                  selected: target == selected,
                  activeAccent: accent,
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
    required this.activeAccent,
    required this.onPressed,
  });

  final QuickAddTarget target;
  final bool selected;
  final Color activeAccent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final targetColor = target.isProject
        ? ProjectPalette.resolve(target.colorKey).accent
        : colors.textMuted;
    final foreground = selected ? activeAccent : colors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Quick Add target: ${target.name}',
      child: ShadButton.ghost(
        key: ValueKey<String>(
          'quick-add-target-${target.projectId ?? 'inbox'}',
        ),
        onPressed: onPressed,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: foreground,
        hoverForegroundColor: foreground,
        backgroundColor: selected
            ? activeAccent.withValues(alpha: .12)
            : colors.surfaceSubtle,
        hoverBackgroundColor: selected
            ? activeAccent.withValues(alpha: .14)
            : colors.surfaceSubtle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (target.isInbox)
              Icon(AppIcons.inbox, size: 17, color: targetColor)
            else
              ProjectIcon(
                iconKey: target.iconKey,
                color: targetColor,
                size: 17,
              ),
            const SizedBox(width: 8),
            Text(
              target.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Icon(AppIcons.chevronDown, size: 15, color: foreground),
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
    required this.accent,
    required this.onSubmit,
    required this.onCancel,
    required this.onCancelFromKeyboard,
  });

  final QuickAddController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final AppColorScheme colors;
  final Color accent;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onCancel;
  final VoidCallback onCancelFromKeyboard;

  @override
  Widget build(BuildContext context) {
    final error = controller.error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              controller.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuickAddInput(
          controller: controller,
          textController: textController,
          focusNode: focusNode,
          colors: colors,
          accent: accent,
          onSubmit: onSubmit,
          onCancelFromKeyboard: onCancelFromKeyboard,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Spacer(),
            if (controller.error != null) Flexible(child: error),
            ShadButton.ghost(
              onPressed: controller.isSubmitting ? null : onSubmit,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              foregroundColor: colors.white,
              hoverForegroundColor: colors.white,
              backgroundColor: accent,
              hoverBackgroundColor: accent.withValues(alpha: .88),
              child: const Text(
                '添加',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            ShadButton.ghost(
              onPressed: onCancel,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: colors.textMuted,
              hoverForegroundColor: colors.textMuted,
              hoverBackgroundColor: colors.surfaceSubtle,
              child: const Text(
                '关闭',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAddInput extends StatelessWidget {
  const _QuickAddInput({
    required this.controller,
    required this.textController,
    required this.focusNode,
    required this.colors,
    required this.accent,
    required this.onSubmit,
    required this.onCancelFromKeyboard,
  });

  final QuickAddController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final AppColorScheme colors;
  final Color accent;
  final Future<void> Function() onSubmit;
  final VoidCallback onCancelFromKeyboard;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.borderStrong),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 2,
                height: 30,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: textController,
                  builder: (context, value, child) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (value.text.isEmpty)
                          Text(
                            '快速记录临时任务...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textFaint,
                              fontSize: 15,
                            ),
                          ),
                        Shortcuts(
                          shortcuts: const <ShortcutActivator, Intent>{
                            SingleActivator(LogicalKeyboardKey.escape):
                                _QuickAddCancelIntent(),
                          },
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              _QuickAddCancelIntent:
                                  CallbackAction<_QuickAddCancelIntent>(
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
                              cursorColor: accent,
                              cursorHeight: 22,
                              backgroundCursorColor: colors.textFaint,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 15,
                                height: 1.2,
                              ),
                              selectionColor: accent.withValues(alpha: .16),
                              strutStyle: const StrutStyle(
                                fontSize: 15,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
