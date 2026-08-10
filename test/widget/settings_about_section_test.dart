import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/app_constants.dart';
import 'package:litetodo/app/theme/app_theme.dart';
import 'package:litetodo/presentation/settings/settings_about_section.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  test('about metadata stays centralized with the packaged version', () {
    expect(AppConstants.appVersion, '1.0.0');
    expect(AppConstants.appBuild, '1');
    expect(AppConstants.appVersionLabel, '1.0.0+1');
    expect(AppConstants.technologyLabel, 'Flutter Desktop · Windows');
  });

  testWidgets('about section fits the reference desktop sizes', (tester) async {
    for (final size in <Size>[const Size(1672, 680), const Size(680, 680)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_host(const AboutSettingsSection()));
      await tester.pump();

      expect(find.text('LiteTodo'), findsOneWidget);
      expect(find.text('1.0.0+1'), findsOneWidget);
      expect(find.text('Flutter Desktop · Windows'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('license catalog loads lazily and opens one license detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        AboutSettingsSection(
          licenseStreamFactory: () => Stream<LicenseEntry>.value(
            const LicenseEntryWithLineBreaks(<String>[
              'demo_package',
            ], 'Demo license paragraph.\n\nSecond paragraph.'),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('about-licenses-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('about-licenses-dialog')),
      findsOneWidget,
    );
    expect(find.text('demo_package'), findsOneWidget);
    expect(find.text('Demo license paragraph.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('license-entry-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('license-paragraph-list')),
      findsOneWidget,
    );
    expect(find.text('Demo license paragraph.'), findsOneWidget);
    expect(find.text('Second paragraph.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('license catalog has stable loading, empty, and error states', (
    tester,
  ) async {
    final controller = StreamController<LicenseEntry>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      _host(
        AboutSettingsSection(licenseStreamFactory: () => controller.stream),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('about-licenses-button')),
    );
    await tester.pump();
    expect(find.text('正在加载许可证...'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('license-dialog-close')),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _host(
        AboutSettingsSection(
          licenseStreamFactory: () => const Stream<LicenseEntry>.empty(),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('about-licenses-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无已注册的第三方许可证。'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('license-dialog-close')),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _host(
        AboutSettingsSection(
          licenseStreamFactory: () =>
              Stream<LicenseEntry>.error(StateError('test failure')),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('about-licenses-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('许可证加载失败'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('license-retry-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('about section supports the dark theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(const AboutSettingsSection(), dark: true));
    await tester.pump();
    expect(find.text('关于 LiteTodo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(Widget child, {bool dark = false}) {
  return ShadApp(
    theme: dark ? AppTheme.darkFor() : AppTheme.lightFor(),
    home: Center(child: SingleChildScrollView(child: child)),
  );
}
