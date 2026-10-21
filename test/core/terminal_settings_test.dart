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
}
