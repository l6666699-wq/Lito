import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_motion.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = '',
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  ShadDialogVariant variant = ShadDialogVariant.primary,
}) {
  return showShadDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: AppMotion.dialogBarrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    variant: variant,
    animateIn: const [
      FadeEffect(duration: AppMotion.dialogEnter, curve: AppMotion.enterCurve),
      ScaleEffect(
        begin: Offset(.985, .985),
        end: Offset(1, 1),
        duration: AppMotion.dialogEnter,
        curve: AppMotion.enterCurve,
      ),
      MoveEffect(
        begin: Offset(0, 6),
        end: Offset.zero,
        duration: AppMotion.dialogEnter,
        curve: AppMotion.enterCurve,
      ),
    ],
    animateOut: const [
      FadeEffect(
        begin: 1,
        end: 0,
        duration: AppMotion.dialogExit,
        curve: AppMotion.exitCurve,
      ),
      ScaleEffect(
        begin: Offset(1, 1),
        end: Offset(.99, .99),
        duration: AppMotion.dialogExit,
        curve: AppMotion.exitCurve,
      ),
      MoveEffect(
        begin: Offset.zero,
        end: Offset(0, 4),
        duration: AppMotion.dialogExit,
        curve: AppMotion.exitCurve,
      ),
    ],
  );
}
