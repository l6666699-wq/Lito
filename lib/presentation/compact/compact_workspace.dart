import 'package:flutter/widgets.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/window_controller.dart';
import '../../application/workspace_controller.dart';
import '../todo/todo_list.dart';
import 'compact_header.dart';

class CompactWorkspace extends StatelessWidget {
  const CompactWorkspace({
    super.key,
    required this.controller,
    required this.windowController,
  });

  final WorkspaceController controller;
  final WindowController windowController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final colors = AppColors.of(context);
        final rows = controller.visibleRows;
        return ColoredBox(
          color: colors.canvas,
          child: Column(
            children: [
              CompactHeader(windowController: windowController),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppMetrics.compactPadding),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(
                        AppMetrics.cardRadius,
                      ),
                    ),
                    child: TodoList(controller: controller, rows: rows),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
