import 'package:conduit/core/theme/app_palette.dart';
import 'package:conduit/core/theme/terminal_appearance.dart';
import 'package:conduit/core/theme/theme_preferences_repository.dart';
import 'package:conduit/features/snippets/domain/terminal_snippet.dart';
import 'package:conduit/features/sftp/domain/sftp_sort_mode.dart';
import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._repository);

  final ThemePreferencesRepository _repository;

  ThemeMode _themeMode = ThemeMode.dark;
  AppPalette _palette = AppPalette.synthwave;
  TerminalFontOption _terminalFont = TerminalFontOption.atkynsonNerdFont;
  double _terminalFontSize = terminalFontSizeDefault;
  TerminalCursorShape _terminalCursorShape = TerminalCursorShape.block;
  int _terminalScrollbackLines = terminalScrollbackDefault;
  double _terminalLineHeight = terminalLineHeightDefault;
  double _terminalPadding = terminalPaddingDefault;
  int _sshKeepAliveSeconds = sshKeepAliveDefault;
  bool _confirmCloseActiveTabs = true;
  bool _sftpShowHiddenFiles = true;
  SftpSortMode _sftpSortMode = SftpSortMode.name;
  List<TerminalKeyboardRow> _terminalKeyboardRows = defaultTerminalKeyboardRows;
  List<TerminalSnippet> _terminalSnippets = const [];
  bool _showGlobalSnippets = true;
  bool _confirmGlobalSnippetSend = false;
  bool _showLocalShell = true;
  bool _terminalMouseInput = false;
  TerminalEnterSequence _terminalEnterSequence = TerminalEnterSequence.cr;

  ThemeMode get themeMode => _themeMode;
  AppPalette get palette => _palette;
  TerminalFontOption get terminalFont => _terminalFont;
  double get terminalFontSize => _terminalFontSize;
  TerminalCursorShape get terminalCursorShape => _terminalCursorShape;
  int get terminalScrollbackLines => _terminalScrollbackLines;
  double get terminalLineHeight => _terminalLineHeight;
  double get terminalPadding => _terminalPadding;
  int get sshKeepAliveSeconds => _sshKeepAliveSeconds;
  bool get confirmCloseActiveTabs => _confirmCloseActiveTabs;
  bool get sftpShowHiddenFiles => _sftpShowHiddenFiles;
  SftpSortMode get sftpSortMode => _sftpSortMode;
  List<TerminalKeyboardRow> get terminalKeyboardRows =>
      List.unmodifiable(_terminalKeyboardRows);
  List<TerminalSnippet> get terminalSnippets =>
      List.unmodifiable(_terminalSnippets);
  bool get showGlobalSnippets => _showGlobalSnippets;
  bool get confirmGlobalSnippetSend => _confirmGlobalSnippetSend;
  bool get showLocalShell => _showLocalShell;
  bool get terminalMouseInput => _terminalMouseInput;
  TerminalEnterSequence get terminalEnterSequence => _terminalEnterSequence;

  Future<void> load() async {
    final preferences = await _repository.load();
    _themeMode = preferences.themeMode;
    _palette = preferences.palette;
    _terminalFont = preferences.terminalFont;
    _terminalFontSize = preferences.terminalFontSize;
    _terminalCursorShape = preferences.terminalCursorShape;
    _terminalScrollbackLines = preferences.terminalScrollbackLines;
    _terminalLineHeight = preferences.terminalLineHeight;
    _terminalPadding = preferences.terminalPadding;
    _sshKeepAliveSeconds = preferences.sshKeepAliveSeconds;
    _confirmCloseActiveTabs = preferences.confirmCloseActiveTabs;
    _sftpShowHiddenFiles = preferences.sftpShowHiddenFiles;
    _sftpSortMode = preferences.sftpSortMode;
    _terminalKeyboardRows = List.of(preferences.terminalKeyboardRows);
    _terminalSnippets = List.of(preferences.terminalSnippets);
    _showGlobalSnippets = preferences.showGlobalSnippets;
    _confirmGlobalSnippetSend = preferences.confirmGlobalSnippetSend;
    _showLocalShell = preferences.showLocalShell;
    _terminalMouseInput = preferences.terminalMouseInput;
    _terminalEnterSequence = preferences.terminalEnterSequence;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> setPalette(AppPalette palette) async {
    if (_palette == palette) {
      return;
    }
    _palette = palette;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalFont(TerminalFontOption font) async {
    if (_terminalFont == font) {
      return;
    }
    _terminalFont = font;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalFontSize(double size) async {
    final normalized = normalizeTerminalFontSize(size);
    if (_terminalFontSize == normalized) {
      return;
    }
    _terminalFontSize = normalized;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalCursorShape(TerminalCursorShape value) async {
    if (_terminalCursorShape == value) return;
    _terminalCursorShape = value;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalScrollbackLines(int value) async {
    final next = normalizeTerminalScrollback(value);
    if (_terminalScrollbackLines == next) return;
    _terminalScrollbackLines = next;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalLineHeight(double value) async {
    final next = normalizeTerminalLineHeight(value);
    if (_terminalLineHeight == next) return;
    _terminalLineHeight = next;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalPadding(double value) async {
    final next = normalizeTerminalPadding(value);
    if (_terminalPadding == next) return;
    _terminalPadding = next;
    notifyListeners();
    await _save();
  }

  Future<void> setSshKeepAliveSeconds(int value) async {
    final next = normalizeSshKeepAlive(value);
    if (_sshKeepAliveSeconds == next) return;
    _sshKeepAliveSeconds = next;
    notifyListeners();
    await _save();
  }

  Future<void> setConfirmCloseActiveTabs(bool value) async {
    if (_confirmCloseActiveTabs == value) return;
    _confirmCloseActiveTabs = value;
    notifyListeners();
    await _save();
  }

  Future<void> setSftpShowHiddenFiles(bool value) async {
    if (_sftpShowHiddenFiles == value) return;
    _sftpShowHiddenFiles = value;
    notifyListeners();
    await _save();
  }

  Future<void> setSftpSortMode(SftpSortMode value) async {
    if (_sftpSortMode == value) return;
    _sftpSortMode = value;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalKeyboardRows(List<TerminalKeyboardRow> rows) async {
    final normalized = <TerminalKeyboardRow>[];
    for (final row in rows) {
      final seen = <TerminalKeyboardAction>{};
      final items = <TerminalKeyboardItem>[];
      for (final item in row.items) {
        final action = item.action;
        if (item.kind == TerminalKeyboardItemKind.builtIn && action != null) {
          if (seen.add(action)) {
            items.add(item);
          }
        } else {
          items.add(item);
        }
      }
      if (items.isEmpty) {
        continue;
      }
      normalized.add(
        TerminalKeyboardRow(
          items: items,
          height: clampTerminalKeyboardRowHeight(row.height),
        ),
      );
    }
    final next = normalized.isEmpty ? defaultTerminalKeyboardRows : normalized;
    if (_listEquals(_terminalKeyboardRows, next)) {
      return;
    }
    _terminalKeyboardRows = List.of(next);
    notifyListeners();
    await _save();
  }

  Future<void> resetTerminalKeyboardRows() {
    return setTerminalKeyboardRows(defaultTerminalKeyboardRows);
  }

  Future<void> setTerminalSnippets(List<TerminalSnippet> snippets) async {
    final seen = <String>{};
    final normalized = <TerminalSnippet>[];
    for (final snippet in snippets) {
      if (!snippet.isValid || !seen.add(snippet.id)) {
        continue;
      }
      normalized.add(snippet);
    }
    if (_listEquals(_terminalSnippets, normalized)) {
      return;
    }
    _terminalSnippets = List.of(normalized);
    notifyListeners();
    await _save();
  }

  Future<void> setShowGlobalSnippets(bool value) async {
    if (_showGlobalSnippets == value) {
      return;
    }
    _showGlobalSnippets = value;
    notifyListeners();
    await _save();
  }

  Future<void> setConfirmGlobalSnippetSend(bool value) async {
    if (_confirmGlobalSnippetSend == value) {
      return;
    }
    _confirmGlobalSnippetSend = value;
    notifyListeners();
    await _save();
  }

  Future<void> setShowLocalShell(bool show) async {
    if (_showLocalShell == show) {
      return;
    }
    _showLocalShell = show;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalMouseInput(bool enabled) async {
    if (_terminalMouseInput == enabled) {
      return;
    }
    _terminalMouseInput = enabled;
    notifyListeners();
    await _save();
  }

  Future<void> setTerminalEnterSequence(TerminalEnterSequence sequence) async {
    if (_terminalEnterSequence == sequence) {
      return;
    }
    _terminalEnterSequence = sequence;
    notifyListeners();
    await _save();
  }

  Future<void> _save() {
    return _repository.save(
      ThemePreferences(
        themeMode: _themeMode,
        palette: _palette,
        terminalFont: _terminalFont,
        terminalFontSize: _terminalFontSize,
        terminalCursorShape: _terminalCursorShape,
        terminalScrollbackLines: _terminalScrollbackLines,
        terminalLineHeight: _terminalLineHeight,
        terminalPadding: _terminalPadding,
        sshKeepAliveSeconds: _sshKeepAliveSeconds,
        confirmCloseActiveTabs: _confirmCloseActiveTabs,
        sftpShowHiddenFiles: _sftpShowHiddenFiles,
        sftpSortMode: _sftpSortMode,
        terminalKeyboardRows: _terminalKeyboardRows,
        terminalSnippets: _terminalSnippets,
        showGlobalSnippets: _showGlobalSnippets,
        confirmGlobalSnippetSend: _confirmGlobalSnippetSend,
        showLocalShell: _showLocalShell,
        terminalMouseInput: _terminalMouseInput,
        terminalEnterSequence: _terminalEnterSequence,
      ),
    );
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
