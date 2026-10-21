import 'package:conduit/core/theme/terminal_appearance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scrollback accepts supported limits only', () {
    expect(normalizeTerminalScrollback(1000), 1000);
    expect(normalizeTerminalScrollback(50000), 50000);
    expect(normalizeTerminalScrollback(-1), terminalScrollbackDefault);
  });

  test('line height and padding stay inside supported steps', () {
    expect(normalizeTerminalLineHeight(1.56), 1.6);
    expect(normalizeTerminalLineHeight(2.0), terminalLineHeightMax);
    expect(normalizeTerminalLineHeight(double.nan), terminalLineHeightDefault);
    expect(normalizeTerminalPadding(11.5), 12);
    expect(normalizeTerminalPadding(-9), terminalPaddingMin);
  });

  test('SSH keepalive honors off and valid intervals', () {
    expect(sshKeepAliveDuration(0), isNull);
    expect(sshKeepAliveDuration(30), const Duration(seconds: 30));
    expect(sshKeepAliveDuration(999), const Duration(seconds: 10));
  });

  test('Focused preset fits the essential controls in a single row', () {
    expect(defaultTerminalKeyboardRows, focusedTerminalKeyboardRows);
    expect(focusedTerminalKeyboardRows, hasLength(1));
    expect(
      focusedTerminalKeyboardRows.single.items.map((item) => item.action),
      [
        TerminalKeyboardAction.escape,
        TerminalKeyboardAction.control,
        TerminalKeyboardAction.alt,
        TerminalKeyboardAction.tab,
        TerminalKeyboardAction.arrowLeft,
        TerminalKeyboardAction.arrowDown,
        TerminalKeyboardAction.arrowUp,
        TerminalKeyboardAction.arrowRight,
        TerminalKeyboardAction.more,
      ],
    );
    expect(
      terminalKeyboardLayoutForRows(focusedTerminalKeyboardRows),
      TerminalKeyboardLayout.focused,
    );
  });

  test('Two-tier preset keeps modifiers separate from navigation', () {
    expect(twoTierTerminalKeyboardRows, hasLength(2));
    expect(
      twoTierTerminalKeyboardRows.first.items.map((item) => item.action),
      containsAll([
        TerminalKeyboardAction.control,
        TerminalKeyboardAction.alt,
        TerminalKeyboardAction.tab,
      ]),
    );
    expect(
      twoTierTerminalKeyboardRows.last.items.map((item) => item.action),
      containsAll([
        TerminalKeyboardAction.arrowLeft,
        TerminalKeyboardAction.arrowDown,
        TerminalKeyboardAction.arrowUp,
        TerminalKeyboardAction.arrowRight,
        TerminalKeyboardAction.snippets,
      ]),
    );
    expect(
      terminalKeyboardLayoutForRows(twoTierTerminalKeyboardRows),
      TerminalKeyboardLayout.twoTier,
    );
    expect(
      terminalKeyboardLayoutForRows([
        twoTierTerminalKeyboardRows.first.copyWith(height: 65),
        twoTierTerminalKeyboardRows.last,
      ]),
      TerminalKeyboardLayout.custom,
    );
  });
}
