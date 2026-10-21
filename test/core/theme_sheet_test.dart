import 'package:conduit/core/presentation/theme_sheet.dart';
import 'package:conduit/core/theme/terminal_appearance.dart';
import 'package:conduit/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_doubles.dart';

void main() {
  testWidgets('global settings updates the shared terminal font and size', (
    tester,
  ) async {
    final repository = InMemoryThemePreferences();
    final controller = ThemeController(repository);
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showGlobalSettingsSheet(
                context: context,
                controller: controller,
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Global settings'), findsOneWidget);
    expect(find.text('Font family'), findsOneWidget);

    await tester.tap(find.text('System mono'));
    await tester.pumpAndSettle();
    expect(controller.terminalFont, TerminalFontOption.systemMonospace);
    expect((await repository.load()).terminalFont,
        TerminalFontOption.systemMonospace);

    await tester.tap(find.byTooltip('Increase font size'));
    await tester.pumpAndSettle();
    expect(controller.terminalFontSize,
        terminalFontSizeDefault + terminalFontSizeStep);
    expect((await repository.load()).terminalFontSize,
        terminalFontSizeDefault + terminalFontSizeStep);

    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    expect(controller.terminalFontSize, terminalFontSizeDefault);
  });

  testWidgets('appearance settings exposes cursor and rendering controls', (
    tester,
  ) async {
    final controller = ThemeController(InMemoryThemePreferences());
    await controller.load();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      Scaffold(body: FilledButton(
        onPressed: () => showThemeSheet(context: context, controller: controller),
        child: const Text('Open appearance'),
      )),
    )));
    await tester.tap(find.text('Open appearance'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cursor shape'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Underline'));
    await tester.pumpAndSettle();
    expect(controller.terminalCursorShape, TerminalCursorShape.underline);
    await tester.scrollUntilVisible(
      find.text('Scrollback history (new tabs)'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Terminal padding'), findsOneWidget);
    expect(find.text('Line spacing'), findsOneWidget);
    expect(find.text('Scrollback history (new tabs)'), findsOneWidget);
  });

  testWidgets('appearance sheet toggles local shell visibility', (
    tester,
  ) async {
    final controller = ThemeController(InMemoryThemePreferences());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showThemeSheet(context: context, controller: controller);
                  },
                  child: const Text('Appearance'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Show local shell'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Show local shell'), findsOneWidget);
    expect(controller.showLocalShell, isTrue);

    await tester.tap(find.text('Show local shell'));
    await tester.pumpAndSettle();

    expect(controller.showLocalShell, isFalse);
  });

  testWidgets('appearance sheet toggles terminal mouse input', (tester) async {
    final controller = ThemeController(InMemoryThemePreferences());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showThemeSheet(context: context, controller: controller);
                  },
                  child: const Text('Appearance'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Send mouse taps'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Send mouse taps'), findsOneWidget);
    expect(controller.terminalMouseInput, isFalse);

    await tester.tap(find.text('Send mouse taps'));
    await tester.pumpAndSettle();

    expect(controller.terminalMouseInput, isTrue);
  });

  testWidgets('appearance sheet changes terminal enter sequence', (
    tester,
  ) async {
    final controller = ThemeController(InMemoryThemePreferences());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showThemeSheet(context: context, controller: controller);
                  },
                  child: const Text('Appearance'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enter sends'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(controller.terminalEnterSequence, TerminalEnterSequence.cr);

    await tester.tap(find.text('CRLF'));
    await tester.pumpAndSettle();

    expect(controller.terminalEnterSequence, TerminalEnterSequence.crlf);
  });

  testWidgets('key row editor adds and saves a custom text key', (
    tester,
  ) async {
    final controller = ThemeController(InMemoryThemePreferences());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showThemeSheet(context: context, controller: controller);
                  },
                  child: const Text('Appearance'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Edit'));
    await tester.pumpAndSettle();
    final initialCount = controller.terminalKeyboardRows.first.items.length;
    await tester.tap(find.widgetWithText(TextButton, 'Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Key Rows (1)'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit keys'));
    await tester.pumpAndSettle();
    expect(find.text('Row 1 Keys ($initialCount)'), findsOneWidget);

    await tester.drag(
      find.byType(ReorderableListView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Custom'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'gs');
    await tester.enterText(find.byType(TextField).at(1), 'git status');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('gs'), findsOneWidget);
    expect(find.text('Row 1 Keys (${initialCount + 1})'), findsOneWidget);
    expect(
      controller.terminalKeyboardRows.first.items.length,
      initialCount + 1,
    );
    expect(tester.getTopLeft(find.text('gs')).dy, greaterThanOrEqualTo(0));
    expect(
      tester.getBottomRight(find.text('gs')).dy,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Done').last);
    await tester.pumpAndSettle();

    final custom = controller.terminalKeyboardRows.first.items.first;
    expect(custom.kind, TerminalKeyboardItemKind.customText);
    expect(custom.label, 'gs');
    expect(custom.text, 'git status');
  });
}
