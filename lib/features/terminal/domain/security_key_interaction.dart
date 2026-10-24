import 'dart:async';

typedef SecurityKeyPinPrompt =
    Future<String?> Function(SecurityKeyPinRequest request);

typedef SecurityKeySelectionPrompt =
    Future<int?> Function(SecurityKeySelectionRequest request);

class SecurityKeyPinRequest {
  const SecurityKeyPinRequest({this.retriesRemaining});

  final int? retriesRemaining;
}

class SecurityKeySelectionRequest {
  const SecurityKeySelectionRequest({required this.labels});

  final List<String> labels;
}

class SecurityKeySelection {
  const SecurityKeySelection(this.index);

  final int? index;
}

class SecurityKeyInteraction {
  SecurityKeyInteraction._();

  static final instance = SecurityKeyInteraction._();

  final _messages = StreamController<String>.broadcast();
  final _messageHandlers = <void Function(String)>[];
  final _pinPrompts = <SecurityKeyPinPrompt>[];
  final _selectionPrompts = <SecurityKeySelectionPrompt>[];

  Stream<String> get messages => _messages.stream;

  /// Registers a synchronous status listener.
  ///
  /// Prefer this over [messages] for short-lived listeners: cancelling a
  /// broadcast-stream subscription during a connection attempt can leave
  /// pending stream work behind in fake-async test environments.
  void addMessageHandler(void Function(String) handler) {
    _messageHandlers.add(handler);
  }

  void removeMessageHandler(void Function(String) handler) {
    _messageHandlers.remove(handler);
  }

  void announce(String message) {
    for (final handler in List.of(_messageHandlers)) {
      handler(message);
    }
    if (!_messages.isClosed) {
      _messages.add(message);
    }
  }

  void registerPinPrompt(SecurityKeyPinPrompt prompt) {
    _pinPrompts.add(prompt);
  }

  void unregisterPinPrompt(SecurityKeyPinPrompt prompt) {
    _pinPrompts.remove(prompt);
  }

  Future<String?> requestPin({int? retriesRemaining}) {
    if (_pinPrompts.isEmpty) {
      return Future<String?>.value();
    }
    return _pinPrompts.last(
      SecurityKeyPinRequest(retriesRemaining: retriesRemaining),
    );
  }

  void registerSelectionPrompt(SecurityKeySelectionPrompt prompt) {
    _selectionPrompts.add(prompt);
  }

  void unregisterSelectionPrompt(SecurityKeySelectionPrompt prompt) {
    _selectionPrompts.remove(prompt);
  }

  Future<SecurityKeySelection?> requestKeySelection(List<String> labels) async {
    if (_selectionPrompts.isEmpty) {
      return null;
    }
    final index = await _selectionPrompts.last(
      SecurityKeySelectionRequest(labels: labels),
    );
    return SecurityKeySelection(index);
  }
}
