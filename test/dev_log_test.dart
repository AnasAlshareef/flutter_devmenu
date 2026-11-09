import 'package:flutter/foundation.dart';
import 'package:flutter_devmenu/flutter_devmenu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final log = DevMenuLog.instance;

  setUp(log.clear);

  test('keeps only the last [capacity] entries, oldest dropped', () {
    log.capacity = 3;
    for (var i = 1; i <= 5; i++) {
      log.add('line $i');
    }
    final messages = log.entries.map((e) => e.message).toList();
    expect(messages, ['line 3', 'line 4', 'line 5']);
  });

  test('revision bumps on add and clear', () {
    log.capacity = 10;
    final before = log.revision.value;
    log.add('x');
    expect(log.revision.value, before + 1);
    log.clear();
    expect(log.revision.value, before + 2);
    expect(log.entries, isEmpty);
  });

  test('captureDebugPrint routes debugPrint into the buffer, once', () {
    log.capacity = 10;
    log.captureDebugPrint();
    log.captureDebugPrint(); // second call must not double-wrap
    debugPrint('hello');
    final hits = log.entries.where((e) => e.message == 'hello').length;
    expect(hits, 1);
  });
}
