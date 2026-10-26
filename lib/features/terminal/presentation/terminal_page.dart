import 'dart:async';

import 'package:conduit/core/presentation/conduit_brand.dart';
import 'package:conduit/core/presentation/system_navigation_insets.dart';
import 'package:conduit/core/presentation/theme_sheet.dart';
import 'package:conduit/core/theme/app_palette.dart';
import 'package:conduit/core/theme/terminal_appearance.dart';
import 'package:conduit/core/theme/theme_controller.dart';
import 'package:conduit/features/terminal/domain/security_key_interaction.dart';
import 'package:conduit/features/terminal/presentation/security_key_picker_dialog.dart';
import 'package:conduit/features/terminal/presentation/security_key_pin_dialog.dart';
import 'package:conduit/features/terminal/presentation/terminal_keyboard_bar.dart';
import 'package:conduit/features/terminal/presentation/terminal_session_controller.dart';
import 'package:conduit/features/terminal/presentation/terminal_workspace_controller.dart';
import 'package:conduit/features/terminal/presentation/widgets/empty_terminal_state.dart';
import 'package:conduit/features/terminal/presentation/widgets/session_tabs.dart';
import 'package:conduit/features/terminal/presentation/widgets/terminal_header.dart';
import 'package:conduit/features/terminal/presentation/widgets/terminal_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({
    required this.workspace,
    required this.themeController,
    super.key,
  });

  final TerminalWorkspaceController workspace;
  final ThemeController themeController;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final _focusNodes = <String, FocusNode>{};
  TerminalSessionController? _focusedSession;
  bool _fullscreen = false;
  bool _tmuxScrollMode = false;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    SecurityKeyInteraction.instance.registerPinPrompt(_promptSecurityKeyPin);
    SecurityKeyInteraction.instance.registerSelectionPrompt(
      _promptSecurityKeySelection,
    );
    widget.workspace.addListener(_handleWorkspaceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusedSession = widget.workspace.activeSession;
      _focusActiveInput();
    });
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _setSystemUiFullscreen(false);
    SecurityKeyInteraction.instance.unregisterPinPrompt(_promptSecurityKeyPin);
    SecurityKeyInteraction.instance.unregisterSelectionPrompt(
      _promptSecurityKeySelection,
    );
    widget.workspace.removeListener(_handleWorkspaceChanged);
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }

  Future<String?> _promptSecurityKeyPin(SecurityKeyPinRequest request) {
    if (!mounted) {
      return Future<String?>.value();
    }
    return showSecurityKeyPinDialog(context, request);
  }

  Future<int?> _promptSecurityKeySelection(
    SecurityKeySelectionRequest request,
  ) {
    if (!mounted) {
      return Future<int?>.value();
    }
    return showSecurityKeyPickerDialog(context, request);
  }

  void _handleWorkspaceChanged() {
    for (final id in _focusNodes.keys.toList()) {
      if (widget.workspace.sessionById(id) == null) {
        final node = _focusNodes.remove(id)!;
        // Let the removed terminal detach its listeners before disposal.
        WidgetsBinding.instance.addPostFrameCallback((_) => node.dispose());
      }
    }
    final active = widget.workspace.activeSession;
    if (active == null || active == _focusedSession) return;
    _focusedSession = active;
    if (_tmuxScrollMode) {
      setState(() => _tmuxScrollMode = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusActiveInput());
  }

  FocusNode _focusNodeFor(TerminalSessionController session) {
    return _focusNodes.putIfAbsent(
      session.id,
      () => FocusNode(debugLabel: 'Terminal ${session.id}'),
    );
  }

  void _focusActiveInput() {
    if (!mounted) {
      return;
    }
    // A compose field owns focus while it is open; its own autofocus restores
    // the soft keyboard after a tab switch.
    final active = widget.workspace.activeSession;
    if (active == null || active.composeMode) {
      return;
    }
    _focusNodeFor(active).requestFocus();
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    _setSystemUiFullscreen(_fullscreen);
  }

  void _setSystemUiFullscreen(bool fullscreen) {
    SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) {
        final palette = widget.themeController.palette;
        return Scaffold(
          body: ListenableBuilder(
            listenable: widget.workspace,
            builder: (context, _) {
              final activeSession = widget.workspace.activeSession;
              final brightness = Theme.of(context).brightness;
              if (activeSession == null) {
                return ConduitBackdrop(
                  palette: palette,
                  child: SafeArea(
                    bottom: shouldApplyBottomSafeArea(context),
                    child: EmptyTerminalState(
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              }
              final focusNode = _focusNodeFor(activeSession);

              final landscape =
                  MediaQuery.orientationOf(context) == Orientation.landscape;
              final gestureNavigation = usesAndroidGestureNavigation(context);
              return SafeArea(
                top: !_fullscreen,
                bottom: shouldApplyBottomSafeArea(context),
                left: !_fullscreen && (!landscape || !gestureNavigation),
                right: !_fullscreen && (!landscape || !gestureNavigation),
                child: Column(
                  children: [
                    if (!_fullscreen) ...[
                      TerminalHeader(
                        session: activeSession,
                        palette: palette,
                        brightness: brightness,
                        onBack: () => Navigator.of(context).pop(),
                        onSettings: () async {
                          await showGlobalSettingsSheet(
                            context: context,
                            controller: widget.themeController,
                          );
                          if (mounted) _focusActiveInput();
                        },
                        onReconnect: () async {
                          await activeSession.disconnect();
                          await activeSession.connect();
                          _focusActiveInput();
                        },
                      ),
                      SessionTabs(
                        workspace: widget.workspace,
                        activeSession: activeSession,
                        palette: palette,
                        brightness: brightness,
                        onChanged: _focusActiveInput,
                        confirmCloseActiveTabs: widget.themeController
                            .confirmCloseActiveTabs,
                        onCreateSession: () {
                          widget.workspace.createSession(activeSession.host);
                          _focusActiveInput();
                        },
                      ),
                    ],
                    Expanded(
                      child: Container(
                        color: palette.terminalBackgroundFor(brightness),
                        // Key the visibility wrapper too, so removing a tab
                        // preserves surviving terminal views and input clients.
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            for (final session in widget.workspace.sessions)
                              Offstage(
                                key: ValueKey('terminal-stage-${session.id}'),
                                offstage: session != activeSession,
                                child: TerminalSurface(
                                  key: ValueKey('terminal-${session.id}'),
                                  session: session,
                                  palette: palette,
                                  brightness: brightness,
                                  fontFamily: widget
                                      .themeController
                                      .terminalFont
                                      .fontFamily,
                                  fontSize:
                                      widget.themeController.terminalFontSize,
                                  cursorShape: widget
                                      .themeController
                                      .terminalCursorShape,
                                  lineHeight:
                                      widget.themeController.terminalLineHeight,
                                  terminalPadding:
                                      widget.themeController.terminalPadding,
                                  onFontSizeChanged: (fontSize) {
                                    unawaited(
                                      widget.themeController
                                          .setTerminalFontSize(fontSize),
                                    );
                                  },
                                  predictiveEchoEnabled:
                                      session.host.predictiveEchoEnabled,
                                  terminalMouseInput:
                                      widget.themeController.terminalMouseInput,
                                  focusNode: _focusNodeFor(session),
                                  inputEnabled: session == activeSession,
                                  tmuxScrollMode:
                                      session == activeSession &&
                                      _tmuxScrollMode,
                                  onExitTmuxScrollMode: () {
                                    setState(() => _tmuxScrollMode = false);
                                    _focusActiveInput();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (activeSession.composeMode)
                      _ComposeInputBar(
                        key: ValueKey('compose-${activeSession.id}'),
                        palette: palette,
                        brightness: brightness,
                        history: activeSession.composeHistory,
                        initialText: activeSession.composeDraft,
                        onDraftChanged: activeSession.updateComposeDraft,
                        onSend: (line) {
                          // Send the line, then deliver Enter as a SEPARATE write a
                          // short moment later. Some remote TUIs (e.g. Claude Code
                          // and other Ink/readline apps) classify a single terminal
                          // read that contains a long line ending in CR as a *paste*
                          // and insert the trailing CR as a literal newline instead
                          // of submitting — so a wrapping compose line silently fails
                          // to send. Delivering Enter in its own read makes it an
                          // isolated keypress that submits regardless of line length.
                          // The session guards that delayed Enter with the connection
                          // generation so switching/reconnecting drops it safely.
                          activeSession.sendComposeLine(line);
                          activeSession.recordComposeLine(line);
                        },
                        onClose: (draft) {
                          activeSession.closeCompose(draft);
                          _focusActiveInput();
                        },
                      )
                    else
                      TerminalKeyboardBar(
                        key: ValueKey('keyboard-${activeSession.id}'),
                        controller: activeSession,
                        focusNode: focusNode,
                        palette: palette,
                        brightness: brightness,
                        rows: widget.themeController.terminalKeyboardRows,
                        globalSnippets: widget.themeController.terminalSnippets,
                        showGlobalSnippets: widget.themeController.showGlobalSnippets,
                        confirmGlobalSnippetSend:
                            widget.themeController.confirmGlobalSnippetSend,
                        fullscreen: _fullscreen,
                        onToggleFullscreen: _toggleFullscreen,
                        composeActive: activeSession.composeMode,
                        onToggleCompose: () => activeSession.setComposeMode(
                          !activeSession.composeMode,
                        ),
                        tmuxPrefixKey: activeSession.host.tmuxPrefixKey,
                        tmuxScrollMode: _tmuxScrollMode,
                        onEnterTmuxScrollMode: () {
                          setState(() => _tmuxScrollMode = true);
                          _focusActiveInput();
                        },
                        onExitTmuxScrollMode: () {
                          setState(() => _tmuxScrollMode = false);
                          _focusActiveInput();
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ComposeInputBar extends StatefulWidget {
  const _ComposeInputBar({
    required this.palette,
    required this.brightness,
    required this.onSend,
    required this.onClose,
    required this.onDraftChanged,
    this.history = const <String>[],
    this.initialText = '',
    super.key,
  });

  final AppPalette palette;
  final Brightness brightness;
  final ValueChanged<String> onSend;

  /// Called for every edit (including recall) so the draft stays with its own
  /// session when the compose field is rebuilt after a tab switch.
  final ValueChanged<String> onDraftChanged;

  /// Called on close with the current (unsent) field text so the caller can
  /// preserve it — closing compose must not silently discard a draft.
  final ValueChanged<String> onClose;

  /// Recently sent lines, oldest first; shown most-recent-first in the recall
  /// menu. Deduplicated by the caller.
  final List<String> history;

  /// Draft text to restore into the field when compose reopens.
  final String initialText;

  @override
  State<_ComposeInputBar> createState() => _ComposeInputBarState();
}

class _ComposeInputBarState extends State<_ComposeInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialText.isNotEmpty) {
      _controller.value = TextEditingValue(
        text: widget.initialText,
        selection: TextSelection.collapsed(offset: widget.initialText.length),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.replaceAll(RegExp(r'[\r\n]'), '');
    _controller.clear();
    widget.onDraftChanged('');
    if (text.isEmpty) {
      return;
    }
    widget.onSend(text);
    _focusNode.requestFocus();
  }

  void _recall(String line) {
    _controller.value = TextEditingValue(
      text: line,
      selection: TextSelection.collapsed(offset: line.length),
    );
    widget.onDraftChanged(line);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.palette.panelFor(widget.brightness),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 4, 6),
        child: Row(
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Recall a sent line',
              color: widget.palette.panelFor(widget.brightness),
              enabled: widget.history.isNotEmpty,
              onSelected: _recall,
              // Opening the menu takes focus off the field (hiding the soft
              // keyboard). _recall restores focus on select; do the same on
              // cancel so the keyboard always returns after the menu closes.
              onCanceled: _focusNode.requestFocus,
              itemBuilder: (context) => [
                for (final line in widget.history.reversed)
                  PopupMenuItem<String>(
                    value: line,
                    child: Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                autocorrect: true,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                onChanged: widget.onDraftChanged,
                inputFormatters: [
                  // Gboard's action key is inconsistent: sometimes 'Send' (fires
                  // onSubmitted), sometimes 'Enter' (inserts a newline into the
                  // field). Catch the newline-insert path here so submitting is
                  // deterministic regardless of which the IME chooses.
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.contains('\n') ||
                        newValue.text.contains('\r')) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _send(),
                      );
                      final clean = newValue.text.replaceAll(
                        RegExp(r'[\r\n]'),
                        '',
                      );
                      return TextEditingValue(
                        text: clean,
                        selection: TextSelection.collapsed(
                          offset: clean.length,
                        ),
                      );
                    }
                    return newValue;
                  }),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Compose a line, Enter to send …',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close compose',
              onPressed: () => widget.onClose(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}
