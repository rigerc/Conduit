import 'dart:async';

import 'package:conduit/core/theme/terminal_appearance.dart';
import 'package:conduit/features/hosts/domain/saved_host.dart';
import 'package:conduit/features/terminal/domain/network_connectivity.dart';
import 'package:conduit/features/terminal/domain/ssh_terminal_repository.dart';
import 'package:conduit/features/terminal/presentation/terminal_session_controller.dart';
import 'package:flutter/foundation.dart';

class TerminalWorkspaceController extends ChangeNotifier {
  TerminalWorkspaceController(this._repository, [this._connectivity])
    : _runtimeId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  final SshTerminalRepository _repository;
  final NetworkConnectivity? _connectivity;

  /// Distinguishes this app runtime from earlier ones when deriving remote
  /// tmux names, so a fresh extra tab never attaches to an old remote session
  /// that happened to use the same per-host number.
  final String _runtimeId;

  final List<TerminalSessionController> _sessions = [];
  final List<TerminalSessionController> _recentSessions = [];
  final Map<String, int> _hostTabCounters = <String, int>{};
  int _activeIndex = 0;
  int _sessionSequence = 0;
  TerminalEnterSequence _enterSequence = TerminalEnterSequence.cr;
  int _scrollbackLines = terminalScrollbackDefault;

  List<TerminalSessionController> get sessions => List.unmodifiable(_sessions);

  TerminalSessionController? get activeSession {
    if (_sessions.isEmpty) {
      return null;
    }
    return _sessions[_activeIndex.clamp(0, _sessions.length - 1)];
  }

  bool get hasSessions => _sessions.isNotEmpty;

  int get liveSessionCount => _sessions
      .where(
        (session) =>
            session.status == TerminalConnectionStatus.connecting ||
            session.status == TerminalConnectionStatus.connected,
      )
      .length;

  bool get hasLiveSessions => liveSessionCount > 0;

  TerminalSessionController? sessionById(String id) {
    for (final session in _sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  void setEnterSequence(TerminalEnterSequence sequence) {
    _enterSequence = sequence;
    for (final session in _sessions) {
      session.enterSequence = sequence;
    }
  }

  void setScrollbackLines(int lines) {
    // Terminal.maxLines is immutable: existing tabs retain their buffer size.
    _scrollbackLines = normalizeTerminalScrollback(lines);
  }

  /// Resumes the host's most recently used surviving tab, or creates its first
  /// tab when the host has none open. Use [createSession] for an explicit "+".
  TerminalSessionController open(SavedHost host) {
    final existing = _mostRecentSessionForHost(host.id);
    if (existing != null) {
      _activateSession(existing);
      return existing;
    }
    return createSession(host);
  }

  /// Always creates and selects another tab for [host], even when one or more
  /// of the host's tabs are already open.
  TerminalSessionController createSession(SavedHost host) {
    final hasHostSession = _sessions.any(
      (session) => session.host.id == host.id,
    );
    final number = (_hostTabCounters[host.id] ?? 0) + 1;
    _hostTabCounters[host.id] = number;
    final id = 's${++_sessionSequence}-$_runtimeId';
    final session = TerminalSessionController(
      host: host,
      repository: _repository,
      connectivity: _connectivity,
      id: id,
      number: number,
      // The first tab reattaches the configured/default remote session. Extra
      // tabs derive a unique name that includes this runtime tab ID, so a new
      // runtime cannot accidentally attach to an old remote session.
      tmuxSessionName: hasHostSession
          ? _derivedTmuxSessionName(host, number, id)
          : null,
      predictiveEchoEnabled: host.predictiveEchoEnabled,
      enterSequence: _enterSequence,
      scrollbackLines: _scrollbackLines,
    );
    session.addListener(notifyListeners);
    _sessions.add(session);
    _activeIndex = _sessions.length - 1;
    _touchRecent(session);
    notifyListeners();
    return session;
  }

  String _derivedTmuxSessionName(SavedHost host, int number, String id) {
    final configured = host.tmuxSessionName.trim();
    final base = configured.isEmpty ? defaultTmuxSessionName : configured;
    return '$base-$number-$id';
  }

  void activate(TerminalSessionController session) {
    _activateSession(session);
  }

  void activateById(String id) {
    final session = sessionById(id);
    if (session != null) {
      _activateSession(session);
    }
  }

  Future<void> closeById(String id) async {
    final session = sessionById(id);
    if (session != null) {
      await close(session);
    }
  }

  void _activateSession(TerminalSessionController session) {
    final index = _sessions.indexOf(session);
    if (index == -1) {
      return;
    }
    _touchRecent(session);
    if (index == _activeIndex) {
      return;
    }
    _activeIndex = index;
    notifyListeners();
  }

  TerminalSessionController? _mostRecentSessionForHost(String hostId) {
    for (final session in _recentSessions.reversed) {
      if (session.host.id == hostId && _sessions.contains(session)) {
        return session;
      }
    }
    return null;
  }

  void _touchRecent(TerminalSessionController session) {
    _recentSessions.remove(session);
    _recentSessions.add(session);
  }

  Future<void> close(TerminalSessionController session) async {
    final index = _sessions.indexOf(session);
    if (index == -1) {
      return;
    }

    _sessions.removeAt(index);
    _recentSessions.remove(session);
    if (_sessions.isEmpty) {
      _activeIndex = 0;
    } else if (_activeIndex >= _sessions.length) {
      _activeIndex = _sessions.length - 1;
    } else if (index < _activeIndex) {
      _activeIndex -= 1;
    }
    final fallback = activeSession;
    if (fallback != null) {
      _touchRecent(fallback);
    }
    notifyListeners();

    session.removeListener(notifyListeners);
    await session.disconnect();
    session.dispose();
  }

  Future<void> closeAll() async {
    final sessions = List<TerminalSessionController>.from(_sessions);
    _sessions.clear();
    _recentSessions.clear();
    _activeIndex = 0;
    notifyListeners();

    for (final session in sessions) {
      session.removeListener(notifyListeners);
      await session.disconnect();
      session.dispose();
    }
  }

  @override
  void dispose() {
    for (final session in _sessions) {
      session.removeListener(notifyListeners);
      session.dispose();
    }
    _sessions.clear();
    _recentSessions.clear();
    super.dispose();
  }
}
