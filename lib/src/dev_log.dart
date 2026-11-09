import 'package:flutter/foundation.dart';

/// One captured log line with the time it arrived.
class DevLogEntry {
  DevLogEntry(this.message) : time = DateTime.now();

  final String message;
  final DateTime time;
}

/// In-memory ring buffer of recent log lines, shown in the dev menu's Logs tab.
///
/// Keeps the last [capacity] entries. Either push lines yourself with [add],
/// or call [captureDebugPrint] once at startup to route every `debugPrint`
/// through here with no other code change.
class DevMenuLog {
  DevMenuLog._();

  static final DevMenuLog instance = DevMenuLog._();

  /// Most entries kept; older ones drop off the front.
  int capacity = 500;

  final List<DevLogEntry> _entries = [];

  /// Bumped on every change so a [ValueListenableBuilder] can rebuild the list.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<DevLogEntry> get entries => List.unmodifiable(_entries);

  void add(String message) {
    _entries.add(DevLogEntry(message));
    // shortcut: removeAt(0) is O(n); fine at capacity 500, swap for a deque
    // if you ever raise capacity into the thousands.
    while (_entries.length > capacity) {
      _entries.removeAt(0);
    }
    revision.value++;
  }

  void clear() {
    _entries.clear();
    revision.value++;
  }

  bool _capturing = false;

  /// Route `debugPrint` through this buffer too, so logs you already print
  /// show up in the menu. Safe to call more than once. Call in debug only.
  void captureDebugPrint() {
    if (_capturing) return;
    _capturing = true;
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) add(message);
      original(message, wrapWidth: wrapWidth);
    };
  }
}
