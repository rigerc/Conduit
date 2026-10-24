import 'dart:async';
import 'dart:convert';

import 'package:conduit/core/theme/app_palette.dart';
import 'package:conduit/core/theme/terminal_appearance.dart';
import 'package:conduit/core/theme/theme_controller.dart';
import 'package:conduit/features/hosts/domain/saved_host.dart';
import 'package:conduit/features/snippets/domain/terminal_snippet.dart';
import 'package:conduit/features/terminal/presentation/terminal_keyboard_bar.dart';
import 'package:conduit/features/terminal/presentation/terminal_page.dart';
import 'package:conduit/features/terminal/presentation/terminal_session_controller.dart';
import 'package:conduit/features/terminal/presentation/terminal_workspace_controller.dart';
import 'package:conduit/features/terminal/presentation/widgets/session_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_doubles.dart';

SavedHost _productionHost({
  bool tmux = false,
  String tmuxName = defaultTmuxSessionName,
  String startDirectory = '',
}) {
  return buildHost('production').copyWith(
    name: 'Production',
    startTmuxOnConnect: tmux,
    tmuxSessionName: tmuxName,
    tmuxStartDirectory: startDirectory,
  );
}

String _sentText(WritableTerminalSession session) {
  return session.sent.map((bytes) => utf8.decode(bytes)).join();
}

Finder _snippetsMenuButton() {
  return find.byWidgetPredicate(
    (widget) => widget is PopupMenuButton && widget.tooltip == 'Snippets',
  );
}

Future<void> _openSnippetsMenu(WidgetTester tester) async {
  final dynamic state = tester.state(_snippetsMenuButton());
  // ignore: avoid_dynamic_calls
  state.showButtonMenu();
  await tester.pumpAndSettle();
}

void main() {
  group('workspace sessions', () {
    test('creates multiple stable-numbered tabs for one host', () {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();

      final first = workspace.open(host);
      final second = workspace.createSession(host);
      final third = workspace.createSession(host);

      expect(workspace.sessions, [first, second, third]);
      expect({first.id, second.id, third.id}, hasLength(3));
      expect([first.number, second.number, third.number], [1, 2, 3]);
      expect(first.tabLabel, 'Production · 1');
      expect(second.tabLabel, 'Production · 2');
      expect(third.tabLabel, 'Production · 3');
      expect(workspace.activeSession, same(third));
      expect(repository.connectCounts, isEmpty);
    });

    test('does not renumber or reuse numbers after a sibling closes', () async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();

      final first = workspace.open(host);
      final second = workspace.createSession(host);
      final third = workspace.createSession(host);
      await workspace.close(first);

      expect(workspace.sessions, [second, third]);
      expect(second.number, 2);
      expect(third.number, 3);
      expect(second.tabLabel, 'Production · 2');
      expect(third.tabLabel, 'Production · 3');

      final fourth = workspace.createSession(host);
      expect(fourth.number, 4);
      expect(fourth.tabLabel, 'Production · 4');
      expect(fourth.id, isNot(isIn([first.id, second.id, third.id])));
    });

    test('open resumes the host MRU tab while create always adds one', () {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final production = _productionHost();
      final staging = buildHost('staging').copyWith(name: 'Staging');

      final productionFirst = workspace.open(production);
      final stagingFirst = workspace.open(staging);
      final productionSecond = workspace.createSession(production);
      final stagingSecond = workspace.createSession(staging);

      workspace.activate(productionFirst);
      expect(workspace.open(production), same(productionFirst));
      expect(workspace.open(staging), same(stagingSecond));

      workspace.activate(stagingFirst);
      expect(workspace.open(staging), same(stagingFirst));
      expect(workspace.sessions, hasLength(4));
      expect(workspace.sessions, contains(productionSecond));
    });

    test('closing the active tab falls back to its sibling and MRU', () async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();

      final first = workspace.open(host);
      final second = workspace.createSession(host);
      final third = workspace.createSession(host);

      workspace.activate(second);
      await workspace.close(second);
      expect(workspace.activeSession, same(third));

      await workspace.close(third);
      expect(workspace.activeSession, same(first));
      expect(workspace.open(host), same(first));
    });

    test('closing a background tab keeps the active selection', () async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();

      final first = workspace.open(host);
      final second = workspace.createSession(host);
      final third = workspace.createSession(host);
      workspace.activate(second);

      await workspace.close(first);
      expect(workspace.activeSession, same(second));
      expect(workspace.sessions, [second, third]);
    });

    test('closing a tab during a pending connect closes only that tab', () async {
      final repository = PendingTerminalRepository();
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();

      final connecting = workspace.open(host);
      final connectFuture = connecting.connect();
      final sibling = workspace.createSession(host);
      expect(workspace.activeSession, same(sibling));

      await workspace.close(connecting);
      final lateTransport = TrackableTerminalSession();
      repository.complete(lateTransport);
      await connectFuture;

      expect(lateTransport.closeCount, 1);
      expect(workspace.sessions, [sibling]);
      expect(workspace.activeSession, same(sibling));
    });

    test('switching activation does not reconnect or close a sibling', () async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();

      final first = workspace.open(host);
      final second = workspace.createSession(host);
      await first.connect();
      await second.connect();

      workspace.activate(first);
      workspace.activate(second);
      workspace.open(host);

      expect(repository.connectCounts[host.id], 2);
      expect(repository.sessions.map((session) {
        return (session as WritableTerminalSession).closeCount;
      }), [0, 0]);
    });

    test('closing affects only the addressed session output and input', () async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();

      final first = workspace.open(host);
      final second = workspace.createSession(host);
      await first.connect();
      await second.connect();
      final firstTransport = repository.sessions[0] as WritableTerminalSession;
      final secondTransport = repository.sessions[1] as WritableTerminalSession;

      firstTransport.emitStdout('first-output');
      secondTransport.emitStdout('second-output');
      await Future<void>.delayed(Duration.zero);

      expect(first.terminal.buffer.getText(), contains('first-output'));
      expect(first.terminal.buffer.getText(), isNot(contains('second-output')));
      expect(second.terminal.buffer.getText(), contains('second-output'));
      expect(second.terminal.buffer.getText(), isNot(contains('first-output')));

      first.sendText('to-first');
      second.sendText('to-second');
      expect(_sentText(firstTransport), 'to-first');
      expect(_sentText(secondTransport), 'to-second');

      await workspace.close(first);
      expect(second.status, TerminalConnectionStatus.connected);
      expect(secondTransport.closeCount, 0);
      expect(workspace.activeSession, same(second));
    });

    test('extra tabs derive unique quoted tmux names and retain them', () async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost(
        tmux: true,
        tmuxName: 'work session',
        startDirectory: "~/client's app",
      );

      final first = workspace.open(host);
      final second = workspace.createSession(host);
      final third = workspace.createSession(host);

      expect(
        first.buildTmuxCommandForTesting(),
        "tmux new-session -A -s 'work session' -c '~/client'\\''s app'\r",
      );
      expect(
        second.buildTmuxCommandForTesting(),
        "tmux new-session -A -s 'work session-2-${second.id}' "
        "-c '~/client'\\''s app'\r",
      );
      expect(
        third.buildTmuxCommandForTesting(),
        contains("-s 'work session-3-${third.id}'"),
      );

      await second.connect();
      final firstAttempt = repository.sessions.last as WritableTerminalSession;
      final firstCommand = _sentText(firstAttempt);
      expect(firstCommand, contains("'work session-2-${second.id}'"));

      await second.disconnect();
      await second.connect();
      final secondAttempt = repository.sessions.last as WritableTerminalSession;
      expect(secondAttempt, isNot(same(firstAttempt)));
      expect(_sentText(secondAttempt), contains(firstCommand.trim()));

      await workspace.closeAll();
      final reopened = workspace.open(host);
      expect(reopened.number, 4);
      expect(reopened.buildTmuxCommandForTesting(), first.buildTmuxCommandForTesting());
    });

    test('local shell tabs keep local behavior and independent input', () async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final local = SavedHost.localShell(id: 'local', name: 'Device');

      final first = workspace.open(local);
      final second = workspace.createSession(local);
      expect(first.host.isLocal, isTrue);
      expect(second.host.isLocal, isTrue);
      expect(first.buildTmuxCommandForTesting(), isNull);
      expect(first.tabLabel, 'Device · 1');
      expect(second.tabLabel, 'Device · 2');

      final connecting = first.connect();
      expect(first.status, TerminalConnectionStatus.connecting);
      expect(first.terminal.buffer.getText(), contains('Starting Device...'));
      await connecting;
      first.sendText('local-command');
      expect(
        _sentText(repository.sessions.single as WritableTerminalSession),
        'local-command',
      );
    });
  });

  group('session tabs widget', () {
    testWidgets('shows numbered tabs and switching preserves surfaces', (
      tester,
    ) async {
      final themeController = ThemeController(InMemoryThemePreferences());
      await themeController.load();
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();
      final first = workspace.open(host);
      final second = workspace.createSession(host);

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalPage(
            workspace: workspace,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Production · 1'), findsOneWidget);
      expect(find.text('Production · 2'), findsOneWidget);
      expect(repository.connectCounts[host.id], 2);
      final firstState = tester.state(
        find.byKey(ValueKey('terminal-${first.id}'), skipOffstage: false),
      );
      final secondState = tester.state(
        find.byKey(ValueKey('terminal-${second.id}'), skipOffstage: false),
      );
      expect(firstState, isNot(same(secondState)));

      await tester.tap(find.text('Production · 1'));
      await tester.pumpAndSettle();
      expect(workspace.activeSession, same(first));
      expect(repository.connectCounts[host.id], 2);
      expect(
        tester.state(
          find.byKey(ValueKey('terminal-${first.id}'), skipOffstage: false),
        ),
        same(firstState),
      );
      expect(
        tester.state(
          find.byKey(ValueKey('terminal-${second.id}'), skipOffstage: false),
        ),
        same(secondState),
      );

      final firstTransport = repository.sessions[0] as WritableTerminalSession;
      final secondTransport = repository.sessions[1] as WritableTerminalSession;
      firstTransport.emitStdout('one-tab');
      secondTransport.emitStdout('two-tab');
      await tester.pump();

      expect(first.terminal.buffer.getText(), contains('one-tab'));
      expect(first.terminal.buffer.getText(), isNot(contains('two-tab')));
      expect(second.terminal.buffer.getText(), contains('two-tab'));
      expect(second.terminal.buffer.getText(), isNot(contains('one-tab')));
    });

    testWidgets('plus adds a tab for the active host and selects it', (
      tester,
    ) async {
      final themeController = ThemeController(InMemoryThemePreferences());
      await themeController.load();
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();
      final first = workspace.open(host);
      final other = workspace.createSession(
        buildHost('other').copyWith(name: 'Other'),
      );
      workspace.activate(first);

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalPage(
            workspace: workspace,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('New tab'));
      await tester.pumpAndSettle();

      expect(workspace.sessions, hasLength(3));
      final created = workspace.activeSession!;
      expect(created.host.id, host.id);
      expect(created.id, isNot(first.id));
      expect(created.id, isNot(other.id));
      expect(find.text('Production · 2'), findsOneWidget);
    });

    testWidgets('scrolls the selected tab into view on create and activate', (
      tester,
    ) async {
      final themeController = ThemeController(InMemoryThemePreferences());
      await themeController.load();
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();
      final first = workspace.open(host);
      for (var index = 0; index < 7; index += 1) {
        workspace.createSession(host);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalPage(
            workspace: workspace,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabsScrollable = find.descendant(
        of: find.byType(SessionTabs),
        matching: find.byType(Scrollable),
      );
      expect(tabsScrollable, findsOneWidget);
      final position = tester.state<ScrollableState>(tabsScrollable).position;
      expect(position.pixels, greaterThan(0));

      workspace.activate(first);
      await tester.pumpAndSettle();
      expect(position.pixels, 0);

      await tester.tap(find.byTooltip('New tab'));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(workspace.activeSession?.number, 9);
    });

    testWidgets('compose draft and recall stay isolated per session', (
      tester,
    ) async {
      final themeController = ThemeController(InMemoryThemePreferences());
      await themeController.load();
      await themeController.setTerminalKeyboardRows(
        const [
          TerminalKeyboardRow(
            items: [
              TerminalKeyboardItem.builtIn(TerminalKeyboardAction.compose),
            ],
          ),
        ],
      );
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();
      final first = workspace.open(host);
      final second = workspace.createSession(host);
      workspace.activate(first);

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalPage(
            workspace: workspace,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compose'));
      await tester.pumpAndSettle();
      expect(first.composeMode, isTrue);
      expect(second.composeMode, isFalse);

      await tester.enterText(find.byType(TextField), 'draft one');
      await tester.pump();
      expect(first.composeDraft, 'draft one');

      await tester.tap(find.text('Production · 2'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(first.composeDraft, 'draft one');
      expect(second.composeDraft, isEmpty);

      await tester.tap(find.text('Production · 1'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'draft one',
      );

      await tester.tap(find.byTooltip('Close compose'));
      await tester.pumpAndSettle();
      first.recordComposeLine('recalled line');
      await tester.pump();

      await tester.tap(find.text('Compose'));
      await tester.pumpAndSettle();
      expect(first.composeDraft, isEmpty);
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('recalled line'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'recalled line',
      );
      expect(first.composeDraft, 'recalled line');

      await tester.tap(find.text('Production · 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Production · 1'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'recalled line',
      );
      expect(second.composeDraft, isEmpty);
    });

    testWidgets('delayed compose enter goes to its originating session', (
      tester,
    ) async {
      final themeController = ThemeController(InMemoryThemePreferences());
      await themeController.load();
      await themeController.setTerminalKeyboardRows(
        const [
          TerminalKeyboardRow(
            items: [
              TerminalKeyboardItem.builtIn(TerminalKeyboardAction.compose),
            ],
          ),
        ],
      );
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final workspace = TerminalWorkspaceController(repository);
      addTearDown(workspace.dispose);
      final host = _productionHost();
      final first = workspace.open(host);
      final second = workspace.createSession(host);
      workspace.activate(first);

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalPage(
            workspace: workspace,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final firstTransport = repository.sessions[0] as WritableTerminalSession;
      final secondTransport = repository.sessions[1] as WritableTerminalSession;

      await tester.tap(find.text('Compose'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'first line');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      await tester.tap(find.text('Production · 2'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));

      expect(workspace.activeSession, same(second));
      expect(_sentText(firstTransport), 'first line\r');
      expect(_sentText(secondTransport), isEmpty);
    });

    testWidgets('paste is dropped after the transport reconnects', (
      tester,
    ) async {
      final clipboard = Completer<String?>();
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final controller = TerminalSessionController(
        host: _productionHost(),
        repository: repository,
      );
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      await controller.connect();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalKeyboardBar(
              controller: controller,
              focusNode: focusNode,
              palette: AppPalette.catppuccin,
              brightness: Brightness.dark,
              rows: const [
                TerminalKeyboardRow(
                  items: [
                    TerminalKeyboardItem.builtIn(TerminalKeyboardAction.paste),
                  ],
                ),
              ],
              globalSnippets: const [],
              fullscreen: false,
              onToggleFullscreen: () {},
              onEnterTmuxScrollMode: () {},
              onExitTmuxScrollMode: () {},
              tmuxPrefixKey: TmuxPrefixKey.controlB,
              tmuxScrollMode: false,
              readClipboard: () => clipboard.future,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.content_paste_rounded));
      await tester.pump();
      await tester.runAsync(controller.disconnect);
      await tester.runAsync(controller.connect);
      clipboard.complete('stale paste');
      await tester.pump();

      expect(repository.sessions, hasLength(2));
      for (final session in repository.sessions) {
        expect(_sentText(session as WritableTerminalSession), isEmpty);
      }
    });

    testWidgets('confirmed global snippet is dropped after reconnect', (
      tester,
    ) async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final controller = TerminalSessionController(
        host: _productionHost(),
        repository: repository,
      );
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      await controller.connect();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalKeyboardBar(
              controller: controller,
              focusNode: focusNode,
              palette: AppPalette.catppuccin,
              brightness: Brightness.dark,
              rows: const [
                TerminalKeyboardRow(
                  items: [
                    TerminalKeyboardItem.builtIn(
                      TerminalKeyboardAction.snippets,
                    ),
                  ],
                ),
              ],
              globalSnippets: const [
                TerminalSnippet(id: 'global', label: 'Deploy', text: 'deploy'),
              ],
              confirmGlobalSnippetSend: true,
              fullscreen: false,
              onToggleFullscreen: () {},
              onEnterTmuxScrollMode: () {},
              onExitTmuxScrollMode: () {},
              tmuxPrefixKey: TmuxPrefixKey.controlB,
              tmuxScrollMode: false,
            ),
          ),
        ),
      );

      await _openSnippetsMenu(tester);
      await tester.tap(find.text('Deploy'));
      await tester.pumpAndSettle();
      expect(find.text('Send global snippet?'), findsOneWidget);

      await tester.runAsync(controller.disconnect);
      await tester.runAsync(controller.connect);
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(repository.sessions, hasLength(2));
      expect(
        _sentText(repository.sessions.last as WritableTerminalSession),
        isEmpty,
      );
    });

    testWidgets('held repeat keys stop after a reconnect generation', (
      tester,
    ) async {
      final repository = ScriptedTerminalRepository(
        (host, attempt) => WritableTerminalSession(),
      );
      final controller = TerminalSessionController(
        host: _productionHost(),
        repository: repository,
      );
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      await controller.connect();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalKeyboardBar(
              controller: controller,
              focusNode: focusNode,
              palette: AppPalette.catppuccin,
              brightness: Brightness.dark,
              rows: const [
                TerminalKeyboardRow(
                  items: [
                    TerminalKeyboardItem.builtIn(
                      TerminalKeyboardAction.arrowDown,
                    ),
                  ],
                ),
              ],
              globalSnippets: const [],
              fullscreen: false,
              onToggleFullscreen: () {},
              onEnterTmuxScrollMode: () {},
              onExitTmuxScrollMode: () {},
              tmuxPrefixKey: TmuxPrefixKey.controlB,
              tmuxScrollMode: false,
            ),
          ),
        ),
      );

      final gesture = await tester.press(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final transport = repository.sessions.single as WritableTerminalSession;
      expect(transport.sent, hasLength(1));

      await tester.runAsync(controller.disconnect);
      await tester.runAsync(controller.connect);
      final reconnected = repository.sessions.last as WritableTerminalSession;
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();

      expect(transport.sent, hasLength(1));
      expect(reconnected.sent, isEmpty);
    });
  });
}
