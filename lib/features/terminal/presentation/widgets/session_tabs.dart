import 'package:conduit/core/theme/app_palette.dart';
import 'package:conduit/features/terminal/presentation/terminal_session_controller.dart';
import 'package:conduit/features/terminal/presentation/terminal_workspace_controller.dart';
import 'package:flutter/material.dart';

class SessionTabs extends StatefulWidget {
  const SessionTabs({
    required this.workspace,
    required this.activeSession,
    required this.palette,
    required this.brightness,
    required this.onChanged,
    this.confirmCloseActiveTabs = true,
    this.onCreateSession,
    super.key,
  });

  final TerminalWorkspaceController workspace;
  final TerminalSessionController activeSession;
  final AppPalette palette;
  final Brightness brightness;
  final VoidCallback onChanged;
  final bool confirmCloseActiveTabs;
  final VoidCallback? onCreateSession;

  @override
  State<SessionTabs> createState() => _SessionTabsState();
}

class _SessionTabsState extends State<SessionTabs> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _tabKeys = <String, GlobalKey>{};
  String? _lastActiveSessionId;
  int _lastSessionCount = 0;

  @override
  void initState() {
    super.initState();
    _lastActiveSessionId = widget.activeSession.id;
    _lastSessionCount = widget.workspace.sessions.length;
    _scheduleEnsureActiveVisible();
  }

  @override
  void didUpdateWidget(covariant SessionTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeId = widget.activeSession.id;
    final sessionCount = widget.workspace.sessions.length;
    if (activeId != _lastActiveSessionId ||
        sessionCount != _lastSessionCount) {
      _lastActiveSessionId = activeId;
      _lastSessionCount = sessionCount;
      _scheduleEnsureActiveVisible();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleEnsureActiveVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _tabKeys[widget.activeSession.id]?.currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void _forgetClosedTabs() {
    _tabKeys.removeWhere(
      (id, _) => widget.workspace.sessionById(id) == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.workspace.sessions;
    _forgetClosedTabs();
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: widget.palette.canvasFor(widget.brightness),
        border: Border(
          bottom: BorderSide(color: widget.palette.hairlineFor(widget.brightness)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  for (final (index, session) in sessions.indexed) ...[
                    if (index > 0) const SizedBox(width: 4),
                    _SessionTab(
                      key: _tabKeys.putIfAbsent(session.id, GlobalKey.new),
                      session: session,
                      selected: session.id == widget.activeSession.id,
                      palette: widget.palette,
                      brightness: widget.brightness,
                      onTap: () {
                        widget.workspace.activateById(session.id);
                        widget.onChanged();
                      },
                      onClose: () => _closeTab(context, session),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.onCreateSession != null)
            _AddTabButton(
              palette: widget.palette,
              brightness: widget.brightness,
              onPressed: widget.onCreateSession!,
            ),
        ],
      ),
    );
  }

  Future<void> _closeTab(
    BuildContext context,
    TerminalSessionController session,
  ) async {
    if (widget.confirmCloseActiveTabs && session.isConnectedOrConnecting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Close active tab?'),
          content: Text('Disconnect ${session.tabLabel} and close its tab?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Close tab'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
    }
    await widget.workspace.closeById(session.id);
    if (!context.mounted) {
      return;
    }
    widget.onChanged();
    if (!widget.workspace.hasSessions) {
      Navigator.of(context).pop();
    }
  }
}

class _AddTabButton extends StatelessWidget {
  const _AddTabButton({
    required this.palette,
    required this.brightness,
    required this.onPressed,
  });

  final AppPalette palette;
  final Brightness brightness;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, left: 2),
      child: SizedBox(
        width: 30,
        height: 26,
        child: IconButton(
          key: const ValueKey('terminal-add-tab'),
          tooltip: 'New tab',
          iconSize: 18,
          padding: EdgeInsets.zero,
          color: palette.mutedForegroundFor(brightness),
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  const _SessionTab({
    required this.session,
    required this.selected,
    required this.palette,
    required this.brightness,
    required this.onTap,
    required this.onClose,
    super.key,
  });

  final TerminalSessionController session;
  final bool selected;
  final AppPalette palette;
  final Brightness brightness;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final foreground = palette.foregroundFor(brightness);
    final muted = palette.mutedForegroundFor(brightness);
    final accent = palette.accent;
    final background = selected
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.14),
            palette.panelFor(brightness),
          )
        : palette.panelFor(brightness);
    final border = selected
        ? accent.withValues(alpha: 0.55)
        : palette.hairlineFor(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 190,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            children: [
              _StatusDot(status: session.status),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  session.tabLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 26,
                height: 26,
                child: IconButton(
                  tooltip: 'Close',
                  iconSize: 14,
                  padding: EdgeInsets.zero,
                  color: muted,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final TerminalConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TerminalConnectionStatus.connected => const Color(0xFF22C55E),
      TerminalConnectionStatus.connecting => const Color(0xFFEAB308),
      TerminalConnectionStatus.failed => Theme.of(context).colorScheme.error,
      TerminalConnectionStatus.idle ||
      TerminalConnectionStatus.disconnected => const Color(0xFF64748B),
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
